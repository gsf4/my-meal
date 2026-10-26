class AppConstants {
  static const String appName = 'My Meal';

  // Chaves de SharedPreferences
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyDailyCalories = 'daily_calories_goal';
  static const String keyDailyProtein = 'daily_protein_goal';
  static const String keyDailyCarbs = 'daily_carbs_goal';
  static const String keyDailyFat = 'daily_fat_goal';

  // Metas nutricionais padrão
  static const double defaultCalories = 2000.0;
  static const double defaultProtein = 150.0;
  static const double defaultCarbs = 200.0;
  static const double defaultFat = 65.0;

  // Modelo Gemini padrão
  static const String keyGeminiModel = 'gemini_model';
  static const String defaultGeminiModel = 'gemini-2.5-flash';
  static const List<String> fallbackGeminiModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
  ];
}
