import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';

class GeminiVoiceService {
  final FoodRepository _foodRepository;
  final http.Client _httpClient;

  GeminiVoiceService({
    FoodRepository? foodRepository,
    http.Client? httpClient,
  })  : _foodRepository = foodRepository ?? FoodRepository(),
        _httpClient = httpClient ?? http.Client();

  /// Consulta a API do Google para listar todos os modelos suportados pela chave informada
  Future<List<String>> listAvailableModels(String apiKey) async {
    try {
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        'v1beta/models',
        {'key': apiKey.trim()},
      );
      final response = await _httpClient.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>? ?? [];
        final List<String> supported = [];
        for (final item in models) {
          final m = item as Map<String, dynamic>;
          final methods = (m['supportedGenerationMethods'] as List<dynamic>? ?? []);
          if (methods.contains('generateContent')) {
            var name = m['name'] as String? ?? '';
            name = name.replaceFirst(RegExp(r'^models/'), '');
            if (name.isNotEmpty) {
              supported.add(name);
            }
          }
        }
        return supported;
      }
    } catch (_) {
      // Ignora falhas de conexão para usar fallback local
    }
    return [];
  }

  /// Resolve o melhor modelo ativo disponível
  Future<String> resolveBestModel(String apiKey, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final savedModel = prefs.getString(AppConstants.keyGeminiModel);
      if (savedModel != null && savedModel.trim().isNotEmpty) {
        return savedModel.trim();
      }
    }

    final availableModels = await listAvailableModels(apiKey);
    String selectedModel = AppConstants.defaultGeminiModel;

    if (availableModels.isNotEmpty) {
      // Prioridade 1: Modelos Flash 2.5
      final flash25 = availableModels.firstWhere(
        (m) => m.contains('flash') && m.contains('2.5'),
        orElse: () => '',
      );
      if (flash25.isNotEmpty) {
        selectedModel = flash25;
      } else {
        // Prioridade 2: Modelos Flash 2.0
        final flash20 = availableModels.firstWhere(
          (m) => m.contains('flash') && m.contains('2.0'),
          orElse: () => '',
        );
        if (flash20.isNotEmpty) {
          selectedModel = flash20;
        } else {
          // Prioridade 3: Qualquer variante Flash (ex: gemini-1.5-flash-latest, etc)
          final anyFlash = availableModels.firstWhere(
            (m) => m.contains('flash'),
            orElse: () => '',
          );
          if (anyFlash.isNotEmpty) {
            selectedModel = anyFlash;
          } else {
            // Prioridade 4: Primeiro modelo com generateContent
            selectedModel = availableModels.first;
          }
        }
      }
      await prefs.setString(AppConstants.keyGeminiModel, selectedModel);
    }

    return selectedModel;
  }

  Future<VoiceMealResult> processAudioMeal({
    required String audioPath,
    required String apiKey,
  }) async {
    final cleanApiKey = apiKey.trim();
    if (cleanApiKey.isEmpty) {
      throw Exception(
        'Chave da API do Gemini não configurada. '
        'Por favor, adicione sua chave nas Configurações do app ou no arquivo .env.',
      );
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('Arquivo de áudio não encontrado para processamento.');
    }

    final audioBytes = await audioFile.readAsBytes();

    const promptText = '''
Você é um assistente de nutrição em português do aplicativo My Meal.
Analise com atenção a fala do usuário no áudio fornecido e extraia todos os alimentos consumidos, suas quantidades convertidas para gramas e as estimativas nutricionais por 100g.

Retorne estritamente um JSON no seguinte formato:
{
  "meal_type": "breakfast" | "lunch" | "snack" | "dinner" | "night_snack",
  "items": [
    {
      "spoken_name": "Nome comum do alimento em português",
      "grams": 150.0,
      "estimated_calories_per_100g": 120.0,
      "estimated_protein_per_100g": 20.0,
      "estimated_carbs_per_100g": 0.0,
      "estimated_fat_per_100g": 3.0
    }
  ]
}

Regras obrigatórias:
1. Converta qualquer medida caseira ou coloquial dita no áudio para o peso aproximado em gramas (ex: 1 ovo = 50g; 1 colher de sopa de azeite = 13g; 1 fatia de pão = 25g; 1 filé de frango médio = 120g; 1 xícara de arroz = 160g; 1 concha de feijão = 130g).
2. Se o usuário citar explicitamente a refeição (ex: "no almoço comi...", "café da manhã", "janta"), defina "meal_type" adequadamente. Se não citar, utilize a refeição mais compatível com o tipo de alimento.
3. Se não for possível identificar nenhum alimento no áudio, retorne "items": [].
''';

    final content = [
      Content.multi([
        DataPart('audio/m4a', audioBytes),
        TextPart(promptText),
      ]),
    ];

    Future<String> executeGenerationWith(String modelIdentifier) async {
      final genModel = GenerativeModel(
        model: modelIdentifier,
        apiKey: cleanApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      final response = await genModel.generateContent(content);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Nenhuma resposta retornada pela IA do Gemini.');
      }
      return text;
    }

    var activeModel = await resolveBestModel(cleanApiKey);
    String? responseText;

    try {
      responseText = await executeGenerationWith(activeModel);
    } catch (e) {
      final errLower = e.toString().toLowerCase();
      final isModelError = errLower.contains('not found') ||
          errLower.contains('not supported') ||
          errLower.contains('404') ||
          errLower.contains('is not found for api version');

      if (isModelError) {
        // Tenta redescobrir o modelo ativo consultando a API
        final refreshedModel = await resolveBestModel(cleanApiKey, forceRefresh: true);
        if (refreshedModel != activeModel) {
          try {
            activeModel = refreshedModel;
            responseText = await executeGenerationWith(activeModel);
          } catch (_) {
            // Continua para a lista estática de fallback caso ainda falhe
          }
        }

        // Se ainda não obteve resposta, itera pela lista de fallbacks conhecidos
        if (responseText == null) {
          for (final candidate in AppConstants.fallbackGeminiModels) {
            if (candidate == activeModel) continue;
            try {
              responseText = await executeGenerationWith(candidate);
              // Salva o modelo que funcionou para as próximas chamadas
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(AppConstants.keyGeminiModel, candidate);
              break;
            } catch (_) {
              // Tenta o próximo candidato
            }
          }
        }
      }

      // Se após todas as tentativas não obteve sucesso, relança a exceção original
      if (responseText == null) {
        rethrow;
      }
    }

    return await _parseGeminiResponse(responseText);
  }

  Future<VoiceMealResult> _parseGeminiResponse(String rawText) async {
    // Limpeza de blocos de código se vierem no formato markdown
    var cleanJson = rawText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final Map<String, dynamic> parsed = jsonDecode(cleanJson);

    // Tipo de refeição sugerido
    final rawMealType = parsed['meal_type'] as String? ?? 'lunch';
    final suggestedMealType = MealType.fromString(rawMealType);

    final rawItems = parsed['items'] as List<dynamic>? ?? [];
    final List<VoiceDetectedFoodItem> detectedItems = [];

    for (final rawItem in rawItems) {
      final map = rawItem as Map<String, dynamic>;
      final spokenName = (map['spoken_name'] as String? ?? '').trim();
      final grams = (map['grams'] as num?)?.toDouble() ?? 100.0;
      final estCal = (map['estimated_calories_per_100g'] as num?)?.toDouble();
      final estProt = (map['estimated_protein_per_100g'] as num?)?.toDouble();
      final estCarbs = (map['estimated_carbs_per_100g'] as num?)?.toDouble();
      final estFat = (map['estimated_fat_per_100g'] as num?)?.toDouble();

      if (spokenName.isEmpty) continue;

      // Cruza com o banco de dados local
      final matchedFood = await _foodRepository.findBestMatch(spokenName);

      detectedItems.add(
        VoiceDetectedFoodItem(
          spokenName: spokenName,
          matchedFood: matchedFood,
          grams: grams,
          estimatedCaloriesPer100g: estCal,
          estimatedProteinPer100g: estProt,
          estimatedCarbsPer100g: estCarbs,
          estimatedFatPer100g: estFat,
        ),
      );
    }

    return VoiceMealResult(
      suggestedMealType: suggestedMealType,
      items: detectedItems,
      rawTranscript: rawText,
    );
  }
}
