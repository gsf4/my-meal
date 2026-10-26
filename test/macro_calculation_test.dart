import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';

void main() {
  group('FoodItem Macro Calculations', () {
    test('Calcula macros proporcionalmente para base per100g', () {
      final chicken = FoodItem(
        id: '1',
        name: 'Peito de Frango',
        unitType: FoodUnitType.per100g,
        calories: 159.0,
        protein: 32.0,
        carbs: 0.0,
        fat: 2.5,
      );

      // 150g de frango
      expect(chicken.calculateCalories(150), closeTo(238.5, 0.01));
      expect(chicken.calculateProtein(150), closeTo(48.0, 0.01));
      expect(chicken.calculateCarbs(150), 0.0);
      expect(chicken.calculateFat(150), closeTo(3.75, 0.01));
    });

    test('Calcula macros proporcionalmente para base per1g', () {
      final oil = FoodItem(
        id: '2',
        name: 'Azeite',
        unitType: FoodUnitType.per1g,
        calories: 8.84,
        protein: 0.0,
        carbs: 0.0,
        fat: 1.0,
      );

      // 13g de azeite
      expect(oil.calculateCalories(13), closeTo(114.92, 0.01));
      expect(oil.calculateFat(13), closeTo(13.0, 0.01));
    });
  });

  group('MealLog and MealType', () {
    test('MealLog calcula totais baseados no alimento vinculado', () {
      final rice = FoodItem(
        id: 'rice-1',
        name: 'Arroz Branco',
        unitType: FoodUnitType.per100g,
        calories: 128.0,
        protein: 2.5,
        carbs: 28.1,
        fat: 0.2,
      );

      final log = MealLog(
        id: 'log-1',
        date: DateTime.now(),
        mealType: MealType.lunch,
        foodId: rice.id,
        consumedAmount: 200.0, // 200g
        food: rice,
      );

      expect(log.calories, closeTo(256.0, 0.01));
      expect(log.protein, closeTo(5.0, 0.01));
      expect(log.carbs, closeTo(56.2, 0.01));
      expect(log.fat, closeTo(0.4, 0.01));
    });

    test('MealType.fromString reconhece variações em português', () {
      expect(MealType.fromString('almoço'), MealType.lunch);
      expect(MealType.fromString('Almoco'), MealType.lunch);
      expect(MealType.fromString('café da manhã'), MealType.breakfast);
      expect(MealType.fromString('janta'), MealType.dinner);
      expect(MealType.fromString('lanches'), MealType.snack);
    });

    test('MealType.fromCurrentTime deduz refeição com base no horário', () {
      final breakfastTime = DateTime(2026, 1, 1, 8, 30);
      expect(MealType.fromCurrentTime(breakfastTime), MealType.breakfast);

      final lunchTime = DateTime(2026, 1, 1, 12, 45);
      expect(MealType.fromCurrentTime(lunchTime), MealType.lunch);

      final snackTime = DateTime(2026, 1, 1, 16, 0);
      expect(MealType.fromCurrentTime(snackTime), MealType.snack);

      final dinnerTime = DateTime(2026, 1, 1, 20, 15);
      expect(MealType.fromCurrentTime(dinnerTime), MealType.dinner);

      final nightSnackTime = DateTime(2026, 1, 1, 23, 0);
      expect(MealType.fromCurrentTime(nightSnackTime), MealType.nightSnack);

      expect(MealType.fromString('ceia'), MealType.nightSnack);
      expect(MealType.fromString('lanche da noite'), MealType.nightSnack);
    });
  });

  group('DailyGoal Model', () {
    test('Retorna valores padrão corretos', () {
      final goal = DailyGoal.defaultGoal();
      expect(goal.calories, 2000.0);
      expect(goal.protein, 150.0);
      expect(goal.carbs, 200.0);
      expect(goal.fat, 65.0);
    });
  });
}
