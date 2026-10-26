import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';

class SettingsRepository {
  Future<String> getGeminiApiKey() async {
    // 1. SharedPreferences (chave informada pelo usuário nas Configurações)
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(AppConstants.keyGeminiApiKey);
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      return savedKey.trim();
    }

    // 2. dotenv (.env carregado)
    try {
      final envKey = dotenv.env['GEMINI_API_KEY'];
      if (envKey != null && envKey.trim().isNotEmpty && envKey != 'sua_chave_aqui') {
        return envKey.trim();
      }
    } catch (_) {
      // Caso o .env não tenha sido inicializado
    }

    // 3. --dart-define=GEMINI_API_KEY=xxx
    const defineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (defineKey.isNotEmpty) {
      return defineKey.trim();
    }

    return '';
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyGeminiApiKey, apiKey.trim());
  }

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString(AppConstants.keyGeminiModel);
    if (savedModel != null &&
        savedModel.trim().isNotEmpty &&
        savedModel != 'gemini-1.5-flash' &&
        savedModel != 'gemini-2.5-flash' &&
        savedModel != 'gemini-2.0-flash') {
      return savedModel.trim();
    }
    return AppConstants.defaultGeminiModel;
  }

  Future<void> saveGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyGeminiModel, model.trim());
  }

  Future<DailyGoal> getDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final calories = prefs.getDouble(AppConstants.keyDailyCalories) ?? AppConstants.defaultCalories;
    final protein = prefs.getDouble(AppConstants.keyDailyProtein) ?? AppConstants.defaultProtein;
    final carbs = prefs.getDouble(AppConstants.keyDailyCarbs) ?? AppConstants.defaultCarbs;
    final fat = prefs.getDouble(AppConstants.keyDailyFat) ?? AppConstants.defaultFat;

    return DailyGoal(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  Future<void> saveDailyGoal(DailyGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyDailyCalories, goal.calories);
    await prefs.setDouble(AppConstants.keyDailyProtein, goal.protein);
    await prefs.setDouble(AppConstants.keyDailyCarbs, goal.carbs);
    await prefs.setDouble(AppConstants.keyDailyFat, goal.fat);
  }
}
