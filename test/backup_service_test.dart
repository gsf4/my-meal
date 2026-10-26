import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/core/services/backup_service.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/repositories/meal_repository.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';
import 'package:my_meal/features/settings/repositories/settings_repository.dart';

// Fake / Mock simples para testar a serialização e lógica de backup
class MockFoodRepo extends FoodRepository {
  final List<FoodItem> foods = [
    FoodItem(id: 'f1', name: 'Arroz', calories: 128, protein: 2.5, carbs: 28, fat: 0.2),
    FoodItem(id: 'f2', name: 'Frango', calories: 159, protein: 32, carbs: 0, fat: 2.5),
  ];

  @override
  Future<List<FoodItem>> getAllFoods({String? query}) async => foods;

  @override
  Future<void> insertFoods(List<FoodItem> newFoods) async {
    foods.addAll(newFoods);
  }
}

class MockMealRepo extends MealRepository {
  @override
  Future<List<MealLog>> getAllMealLogs() async => [];
}

class MockSettingsRepo extends SettingsRepository {
  DailyGoal goal = const DailyGoal(calories: 2200, protein: 160, carbs: 220, fat: 70);

  @override
  Future<DailyGoal> getDailyGoal() async => goal;

  @override
  Future<void> saveDailyGoal(DailyGoal newGoal) async {
    goal = newGoal;
  }
}

void main() {
  group('BackupService Tests', () {
    test('Importa backup JSON com sucesso e atualiza metas e alimentos', () async {
      final foodRepo = MockFoodRepo();
      final mealRepo = MockMealRepo();
      final settingsRepo = MockSettingsRepo();

      final service = BackupService(
        foodRepository: foodRepo,
        mealRepository: mealRepo,
        settingsRepository: settingsRepo,
      );

      final sampleBackupJson = jsonEncode({
        'app': 'My Meal',
        'version': 1,
        'exported_at': '2026-10-26T12:00:00.000',
        'goals': {
          'calories': 2500.0,
          'protein': 180.0,
          'carbs': 250.0,
          'fat': 80.0,
        },
        'foods': [
          {
            'id': 'f3',
            'name': 'Ovo Cozido',
            'unit_type': 'per100g',
            'calories': 146.0,
            'protein': 13.0,
            'carbs': 1.0,
            'fat': 10.0,
            'is_pending_nutrition': 0,
            'created_at': '2026-10-26T12:00:00.000',
          }
        ],
        'meal_logs': [],
      });

      final result = await service.importBackupFromJson(sampleBackupJson);

      expect(result.foodsCount, 1);
      expect(result.goalsUpdated, true);
      expect(settingsRepo.goal.calories, 2500.0);
      expect(settingsRepo.goal.protein, 180.0);
      expect(foodRepo.foods.any((f) => f.name == 'Ovo Cozido'), true);
    });
  });
}
