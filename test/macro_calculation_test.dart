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

    test('Calcula macros para base unit (ex: 2 ovos médios)', () {
      final egg = FoodItem(
        id: '3',
        name: 'Ovo Médio',
        unitType: FoodUnitType.unit,
        calories: 70.0,
        protein: 6.0,
        carbs: 0.5,
        fat: 5.0,
      );

      // 2 ovos
      expect(egg.calculateCalories(2), 140.0);
      expect(egg.calculateProtein(2), 12.0);
      expect(egg.calculateCarbs(2), 1.0);
      expect(egg.calculateFat(2), 10.0);
      expect(egg.unitType.formatAmount(2), '2 un');
      expect(egg.unitType.formatAmount(1), '1 un');
    });

    test('Calcula macros para base slice (ex: 2 fatias de pão)', () {
      final bread = FoodItem(
        id: '4',
        name: 'Pão de Forma',
        unitType: FoodUnitType.slice,
        calories: 65.0,
        protein: 2.3,
        carbs: 12.5,
        fat: 0.8,
      );

      // 2 fatias
      expect(bread.calculateCalories(2), 130.0);
      expect(bread.calculateProtein(2), 4.6);
      expect(bread.calculateCarbs(2), 25.0);
      expect(bread.calculateFat(2), 1.6);
      expect(bread.unitType.formatAmount(1), '1 fatia');
      expect(bread.unitType.formatAmount(2), '2 fatias');
    });

    test('Calcula macros para base per100ml (ex: 250ml de leite)', () {
      final milk = FoodItem(
        id: '5',
        name: 'Leite Desnatado',
        unitType: FoodUnitType.per100ml,
        calories: 35.0,
        protein: 3.4,
        carbs: 4.9,
        fat: 0.1,
      );

      // 250ml
      expect(milk.calculateCalories(250), closeTo(87.5, 0.01));
      expect(milk.calculateProtein(250), closeTo(8.5, 0.01));
      expect(milk.calculateCarbs(250), closeTo(12.25, 0.01));
      expect(milk.calculateFat(250), closeTo(0.25, 0.01));
      expect(milk.unitType.formatAmount(250), '250ml');
    });

    test('FoodUnitType.fromString mapeia termos comuns corretamente', () {
      expect(FoodUnitType.fromString('unidade'), FoodUnitType.unit);
      expect(FoodUnitType.fromString('un'), FoodUnitType.unit);
      expect(FoodUnitType.fromString('fatia'), FoodUnitType.slice);
      expect(FoodUnitType.fromString('100ml'), FoodUnitType.per100ml);
      expect(FoodUnitType.fromString('ml'), FoodUnitType.per1ml);
      expect(FoodUnitType.fromString('colher'), FoodUnitType.tablespoon);
      expect(FoodUnitType.fromString('scoop'), FoodUnitType.scoop);
      expect(FoodUnitType.fromString('porcao'), FoodUnitType.portion);
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
