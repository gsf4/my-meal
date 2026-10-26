import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/repositories/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository();
});

class SelectedDateNotifier extends StateNotifier<DateTime> {
  SelectedDateNotifier() : super(DateTime.now());

  void setDate(DateTime date) {
    state = date;
  }

  void previousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void nextDay() {
    state = state.add(const Duration(days: 1));
  }

  void goToToday() {
    state = DateTime.now();
  }
}

final selectedDateProvider = StateNotifierProvider<SelectedDateNotifier, DateTime>((ref) {
  return SelectedDateNotifier();
});

class MealLogsNotifier extends StateNotifier<AsyncValue<List<MealLog>>> {
  final MealRepository _repository;
  DateTime _currentDate;

  MealLogsNotifier(this._repository, this._currentDate) : super(const AsyncValue.loading()) {
    loadLogs();
  }

  void updateDate(DateTime date) {
    _currentDate = date;
    loadLogs();
  }

  Future<void> loadLogs() async {
    state = const AsyncValue.loading();
    try {
      final logs = await _repository.getMealLogsByDate(_currentDate);
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMealLog({
    required String foodId,
    required MealType mealType,
    required double consumedAmount,
    String? portionId,
    String? portionName,
    double? portionQuantity,
    DateTime? date,
    FoodItem? food,
  }) async {
    final logDate = date ?? _currentDate;
    final log = MealLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: logDate,
      mealType: mealType,
      foodId: foodId,
      consumedAmount: consumedAmount,
      portionId: portionId,
      portionName: portionName,
      portionQuantity: portionQuantity,
      food: food,
    );
    await _repository.insertMealLog(log);
    await loadLogs();
  }

  Future<void> addMultipleMealLogs(List<MealLog> logs) async {
    await _repository.insertMealLogs(logs);
    await loadLogs();
  }

  Future<void> updateMealLog(MealLog log) async {
    await _repository.updateMealLog(log);
    await loadLogs();
  }

  Future<void> updateConsumedAmount(
    String id, 
    double newAmount, {
    double? newPortionQuantity,
  }) async {
    await _repository.updateMealLogAmount(id, newAmount, newPortionQuantity: newPortionQuantity);
    await loadLogs();
  }

  Future<void> deleteMealLog(String id) async {
    await _repository.deleteMealLog(id);
    await loadLogs();
  }

  Future<int> cloneMeal({
    required DateTime sourceDate,
    required MealType sourceMealType,
    required DateTime targetDate,
    required MealType targetMealType,
  }) async {
    final count = await _repository.copyMealLogs(
      sourceDate: sourceDate,
      sourceMealType: sourceMealType,
      targetDate: targetDate,
      targetMealType: targetMealType,
    );
    if (count > 0) {
      await loadLogs();
    }
    return count;
  }
}

final mealLogsProvider = StateNotifierProvider<MealLogsNotifier, AsyncValue<List<MealLog>>>((ref) {
  final repo = ref.watch(mealRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  final notifier = MealLogsNotifier(repo, date);
  return notifier;
});

class ConsumedTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const ConsumedTotals({
    this.calories = 0.0,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fat = 0.0,
  });
}

final consumedTotalsProvider = Provider<ConsumedTotals>((ref) {
  final logsAsync = ref.watch(mealLogsProvider);
  return logsAsync.when(
    data: (logs) {
      double totalCal = 0.0;
      double totalProt = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;

      for (final log in logs) {
        totalCal += log.calories;
        totalProt += log.protein;
        totalCarbs += log.carbs;
        totalFat += log.fat;
      }

      return ConsumedTotals(
        calories: totalCal,
        protein: totalProt,
        carbs: totalCarbs,
        fat: totalFat,
      );
    },
    loading: () => const ConsumedTotals(),
    error: (_, __) => const ConsumedTotals(),
  );
});
