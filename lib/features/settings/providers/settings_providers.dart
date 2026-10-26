import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';
import 'package:my_meal/features/settings/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class DailyGoalNotifier extends StateNotifier<AsyncValue<DailyGoal>> {
  final SettingsRepository _repository;

  DailyGoalNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadGoal();
  }

  Future<void> loadGoal() async {
    state = const AsyncValue.loading();
    try {
      final goal = await _repository.getDailyGoal();
      state = AsyncValue.data(goal);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGoal(DailyGoal goal) async {
    await _repository.saveDailyGoal(goal);
    state = AsyncValue.data(goal);
  }
}

final dailyGoalProvider = StateNotifierProvider<DailyGoalNotifier, AsyncValue<DailyGoal>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return DailyGoalNotifier(repo);
});

class GeminiApiKeyNotifier extends StateNotifier<AsyncValue<String>> {
  final SettingsRepository _repository;

  GeminiApiKeyNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadApiKey();
  }

  Future<void> loadApiKey() async {
    state = const AsyncValue.loading();
    try {
      final key = await _repository.getGeminiApiKey();
      state = AsyncValue.data(key);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateApiKey(String key) async {
    await _repository.saveGeminiApiKey(key);
    state = AsyncValue.data(key.trim());
  }
}

final geminiApiKeyProvider = StateNotifierProvider<GeminiApiKeyNotifier, AsyncValue<String>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return GeminiApiKeyNotifier(repo);
});

class NutritionProgress {
  final DailyGoal goal;
  final ConsumedTotals consumed;

  const NutritionProgress({
    required this.goal,
    required this.consumed,
  });

  double get remainingCalories => goal.calories - consumed.calories;
  double get remainingProtein => goal.protein - consumed.protein;
  double get remainingCarbs => goal.carbs - consumed.carbs;
  double get remainingFat => goal.fat - consumed.fat;

  double get calorieProgress => goal.calories > 0 
      ? (consumed.calories / goal.calories).clamp(0.0, 1.0) 
      : 0.0;

  double get proteinProgress => goal.protein > 0 
      ? (consumed.protein / goal.protein).clamp(0.0, 1.0) 
      : 0.0;

  double get carbsProgress => goal.carbs > 0 
      ? (consumed.carbs / goal.carbs).clamp(0.0, 1.0) 
      : 0.0;

  double get fatProgress => goal.fat > 0 
      ? (consumed.fat / goal.fat).clamp(0.0, 1.0) 
      : 0.0;
}

final nutritionProgressProvider = Provider<NutritionProgress>((ref) {
  final goalAsync = ref.watch(dailyGoalProvider);
  final consumed = ref.watch(consumedTotalsProvider);

  final goal = goalAsync.when(
    data: (g) => g,
    loading: () => DailyGoal.defaultGoal(),
    error: (_, __) => DailyGoal.defaultGoal(),
  );

  return NutritionProgress(goal: goal, consumed: consumed);
});
