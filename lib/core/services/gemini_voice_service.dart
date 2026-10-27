import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meal_planner/services/meal_plan_optimizer.dart';
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
      if (savedModel != null &&
          savedModel.trim().isNotEmpty &&
          savedModel != 'gemini-1.5-flash' &&
          savedModel != 'gemini-2.5-flash' &&
          savedModel != 'gemini-2.0-flash' &&
          savedModel != 'gemini-3.8-flash') {
        return savedModel.trim();
      }
    }

    final availableModels = await listAvailableModels(apiKey);
    String selectedModel = AppConstants.defaultGeminiModel;

    if (availableModels.isNotEmpty) {
      // Prioridade 1: Modelos Flash 3.5 (ex: gemini-3.5-flash-lite - alta capacidade e sem sobrecarga 503)
      final flash35 = availableModels.firstWhere(
        (m) => m.contains('flash') && m.contains('3.5'),
        orElse: () => '',
      );
      if (flash35.isNotEmpty) {
        selectedModel = flash35;
      } else {
        // Prioridade 2: Modelos Flash 3.8
        final flash38 = availableModels.firstWhere(
          (m) => m.contains('flash') && m.contains('3.8'),
          orElse: () => '',
        );
        if (flash38.isNotEmpty) {
          selectedModel = flash38;
        } else {
          // Prioridade 3: Qualquer variante Flash 3.x
          final flash3x = availableModels.firstWhere(
            (m) => m.contains('flash') && m.contains('3.'),
            orElse: () => '',
          );
          if (flash3x.isNotEmpty) {
            selectedModel = flash3x;
          } else {
            // Prioridade 4: Qualquer modelo Flash
            final anyFlash = availableModels.firstWhere(
              (m) => m.contains('flash'),
              orElse: () => '',
            );
            if (anyFlash.isNotEmpty) {
              selectedModel = anyFlash;
            } else {
              // Prioridade 5: Primeiro modelo com generateContent
              selectedModel = availableModels.first;
            }
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

    final responseText = await _sendAudioToGemini(
      audioPath: audioPath,
      apiKey: apiKey,
      promptText: promptText,
    );

    return await _parseGeminiResponse(responseText);
  }

  /// Planeja uma refeição calculando as quantidades ideais dos alimentos falados
  /// para bater a meta de proteína e preencher as calorias restantes do dia.
  Future<VoiceMealResult> planAudioMeal({
    required String audioPath,
    required String apiKey,
    required double remainingCalories,
    required double remainingProtein,
    MealType? targetMealType,
  }) async {
    final defaultTypeStr = targetMealType != null ? targetMealType.name : 'dinner';
    final promptText = '''
Você é um assistente de nutrição em português do aplicativo My Meal especializado em PLANEJAR REFEIÇÕES.
O usuário está gravando um áudio dizendo quais alimentos PRETENDE consumir na refeição para bater as metas restantes do dia.

METAS DO USUÁRIO PARA FECHAR O DIA:
- Proteína restante: ${remainingProtein.toStringAsFixed(1)} g (PRIORIDADE MÁXIMA: deve ser batida obrigatoriamente)
- Calorias restantes: ${remainingCalories.toStringAsFixed(0)} kcal

Analise com atenção a fala do usuário no áudio e extraia todos os alimentos pretendidos (ex: "goma de tapioca e ovos médios", "frango e arroz").
Retorne estritamente um JSON no seguinte formato:
{
  "meal_type": "$defaultTypeStr",
  "items": [
    {
      "spoken_name": "Nome comum do alimento ou porção em português (ex: ovos médios, goma de tapioca)",
      "grams": 100.0,
      "estimated_calories_per_100g": 140.0,
      "estimated_protein_per_100g": 13.0,
      "estimated_carbs_per_100g": 0.0,
      "estimated_fat_per_100g": 9.0
    }
  ]
}

Regras obrigatórias:
1. Mantenha os nomes dos alimentos fiéis ao que o usuário falou, incluindo termos de medidas/porções como "médio", "grande", "fatia", etc. (ex: "ovos médios", "fatia de pão").
2. Se o usuário citar explicitamente a refeição (ex: "no jantar", "lanche da noite"), use o tipo correspondente. Caso contrário, use "$defaultTypeStr".
3. Se não for possível identificar nenhum alimento no áudio, retorne "items": [].
''';

    final responseText = await _sendAudioToGemini(
      audioPath: audioPath,
      apiKey: apiKey,
      promptText: promptText,
    );

    final rawResult = await _parseGeminiResponse(
      responseText,
      defaultMealType: targetMealType,
    );

    // Executa a otimização matemática determinística com base nos alimentos do banco local
    final optimized = MealPlanOptimizer.optimize(
      items: rawResult.items,
      targetCalories: remainingCalories,
      targetProtein: remainingProtein,
    );

    return VoiceMealResult(
      suggestedMealType: targetMealType ?? rawResult.suggestedMealType,
      items: optimized.items,
      rawTranscript: responseText,
    );
  }

  Future<String> _sendAudioToGemini({
    required String audioPath,
    required String apiKey,
    required String promptText,
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
      Object lastError = e;
      final errLower = e.toString().toLowerCase();
      final isRecoverableError = errLower.contains('not found') ||
          errLower.contains('not supported') ||
          errLower.contains('no longer available') ||
          errLower.contains('deprecated') ||
          errLower.contains('update your code') ||
          errLower.contains('404') ||
          errLower.contains('is not found for api version') ||
          errLower.contains('503') ||
          errLower.contains('high demand') ||
          errLower.contains('unavailable') ||
          errLower.contains('overloaded') ||
          errLower.contains('429') ||
          errLower.contains('resource has been exhausted') ||
          errLower.contains('resource_exhausted');

      if (isRecoverableError) {
        // 1. Tenta extrair sugestão direta da mensagem de erro do Google (ex: "use models/gemini-3.8-flash")
        final suggestionMatch = RegExp(r'use (?:models/)?([a-zA-Z0-9\.\-_]+)').firstMatch(e.toString());
        if (suggestionMatch != null) {
          final suggested = suggestionMatch.group(1);
          if (suggested != null && suggested.isNotEmpty && suggested != activeModel) {
            try {
              activeModel = suggested;
              responseText = await executeGenerationWith(activeModel);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(AppConstants.keyGeminiModel, activeModel);
            } catch (err) {
              lastError = err;
            }
          }
        }

        // 2. Se for 503 (alta demanda) ou se ainda não obteve resposta, percorre a lista de fallbacks conhecidos
        if (responseText == null) {
          for (final candidate in AppConstants.fallbackGeminiModels) {
            if (candidate == activeModel) continue;
            try {
              responseText = await executeGenerationWith(candidate);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(AppConstants.keyGeminiModel, candidate);
              break;
            } catch (err) {
              lastError = err;
            }
          }
        }

        // 3. Se ainda não obteve resposta, tenta redescobrir o modelo ativo consultando a API
        if (responseText == null) {
          try {
            final refreshedModel = await resolveBestModel(cleanApiKey, forceRefresh: true);
            if (refreshedModel != activeModel) {
              activeModel = refreshedModel;
              responseText = await executeGenerationWith(activeModel);
            }
          } catch (err) {
            lastError = err;
          }
        }

        // 4. Se o erro for 503 (alta demanda) e todos falharam, espera 1.5s e faz uma tentativa final
        if (responseText == null && (errLower.contains('503') || errLower.contains('high demand'))) {
          await Future.delayed(const Duration(milliseconds: 1500));
          try {
            responseText = await executeGenerationWith(AppConstants.defaultGeminiModel);
          } catch (err) {
            lastError = err;
          }
        }
      }

      // Se após todas as tentativas não obteve sucesso, lança exceção com mensagem amigável
      if (responseText == null) {
        String formatFriendlyError(Object error) {
          final str = error.toString();
          if (str.contains('503') || str.contains('high demand') || str.contains('UNAVAILABLE')) {
            return 'Os servidores do Google Gemini estão com alta demanda temporária no momento (503). Por favor, tente novamente em alguns instantes.';
          }
          if (str.contains('429') || str.contains('RESOURCE_EXHAUSTED')) {
            return 'Limite de requisições do Gemini atingido temporariamente. Aguarde alguns instantes.';
          }
          if (str.contains('API_KEY_INVALID') || str.contains('invalid api key')) {
            return 'Chave de API do Gemini inválida. Verifique sua chave nas Configurações.';
          }
          return str.replaceFirst(RegExp(r'^Exception:\s*'), '');
        }

        throw Exception(formatFriendlyError(lastError));
      }
    }

    return responseText;
  }

  Future<VoiceMealResult> _parseGeminiResponse(
    String rawText, {
    MealType? defaultMealType,
  }) async {
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
    final rawMealType = parsed['meal_type'] as String? ?? (defaultMealType?.name ?? 'lunch');
    final suggestedMealType = defaultMealType ?? MealType.fromString(rawMealType);

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
      String? matchedPortionId;
      String? matchedPortionName;
      double? matchedPortionQty;

      if (matchedFood != null) {
        final portion = _foodRepository.findMatchingPortion(matchedFood, spokenName);
        if (portion != null) {
          matchedPortionId = portion.id;
          matchedPortionName = portion.name;
          matchedPortionQty = (grams / portion.grams).roundToDouble().clamp(1.0, 99.0);
        }
      }

      detectedItems.add(
        VoiceDetectedFoodItem(
          spokenName: spokenName,
          matchedFood: matchedFood,
          grams: grams,
          portionId: matchedPortionId,
          portionName: matchedPortionName,
          portionQuantity: matchedPortionQty,
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
