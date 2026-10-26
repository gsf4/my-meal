import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';

class GeminiVoiceService {
  final FoodRepository _foodRepository;

  GeminiVoiceService({FoodRepository? foodRepository})
      : _foodRepository = foodRepository ?? FoodRepository();

  Future<VoiceMealResult> processAudioMeal({
    required String audioPath,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
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

    final model = GenerativeModel(
      model: AppConstants.defaultGeminiModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );

    const promptText = '''
Você é um assistente de nutrição em português do aplicativo My Meal.
Analise com atenção a fala do usuário no áudio fornecido e extraia todos os alimentos consumidos, suas quantidades convertidas para gramas e as estimativas nutricionais por 100g.

Retorne estritamente um JSON no seguinte formato:
{
  "meal_type": "breakfast" | "lunch" | "dinner" | "snack",
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

    final response = await model.generateContent(content);
    final responseText = response.text;

    if (responseText == null || responseText.trim().isEmpty) {
      throw Exception('Nenhuma resposta retornada pela IA do Gemini.');
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
