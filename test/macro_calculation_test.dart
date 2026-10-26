import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';
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

  group('FoodPortion and Serving Sizes', () {
    test('Calcula macros de porções personalizadas (ex: Ovo médio 55g e Ovo grande 65g)', () {
      const mediumEggPortion = FoodPortion(id: 'p-med', name: 'Ovo médio', grams: 55.0);
      const largeEggPortion = FoodPortion(id: 'p-large', name: 'Ovo grande', grams: 65.0);

      final egg = FoodItem(
        id: 'egg-taco',
        name: 'Ovo Cozido Inteiro',
        unitType: FoodUnitType.per100g,
        calories: 146.0,
        protein: 13.3,
        carbs: 0.6,
        fat: 9.5,
        portions: [mediumEggPortion, largeEggPortion],
      );

      // 1 ovo médio (55g de 100g)
      expect(egg.calculatePortionCalories(mediumEggPortion), closeTo(80.3, 0.1));
      expect(egg.calculatePortionProtein(mediumEggPortion), closeTo(7.315, 0.01));
      expect(egg.calculatePortionCarbs(mediumEggPortion), closeTo(0.33, 0.01));
      expect(egg.calculatePortionFat(mediumEggPortion), closeTo(5.225, 0.01));

      // 2 ovos médios (110g)
      expect(egg.calculatePortionCalories(mediumEggPortion, 2), closeTo(160.6, 0.1));
      expect(egg.calculatePortionProtein(mediumEggPortion, 2), closeTo(14.63, 0.01));

      // 1 ovo grande (65g)
      expect(egg.calculatePortionCalories(largeEggPortion), closeTo(94.9, 0.1));
      expect(egg.calculatePortionProtein(largeEggPortion), closeTo(8.645, 0.01));
    });

    test('Serializa e desserializa FoodPortion em FoodItem (JSON seguro)', () {
      final food = FoodItem(
        id: 'bread-1',
        name: 'Pão Francês',
        unitType: FoodUnitType.per100g,
        calories: 300.0,
        protein: 8.0,
        carbs: 58.6,
        fat: 3.1,
        portions: [
          const FoodPortion(id: 'p-1', name: '1 unidade inteira', grams: 50.0),
          const FoodPortion(id: 'p-2', name: '1 fatia / metade', grams: 25.0),
        ],
      );

      final map = food.toMap();
      expect(map['portions'], isA<String>());

      final restored = FoodItem.fromMap(map);
      expect(restored.portions.length, 2);
      expect(restored.portions[0].name, '1 unidade inteira');
      expect(restored.portions[0].grams, 50.0);
      expect(restored.portions[1].name, '1 fatia / metade');
      expect(restored.portions[1].grams, 25.0);
    });

    test('MealLog com porção formata displayAmount adequadamente', () {
      final bread = FoodItem(
        id: 'b-1',
        name: 'Pão',
        unitType: FoodUnitType.per100g,
        calories: 300.0,
      );

      final logWithPortion = MealLog(
        id: 'l-1',
        date: DateTime.now(),
        mealType: MealType.breakfast,
        foodId: bread.id,
        consumedAmount: 50.0,
        portionId: 'p-1',
        portionName: 'Fatia',
        portionQuantity: 2.0,
        food: bread,
      );

      expect(logWithPortion.displayAmount, '2x Fatia (50g)');

      final logWithoutPortion = MealLog(
        id: 'l-2',
        date: DateTime.now(),
        mealType: MealType.breakfast,
        foodId: bread.id,
        consumedAmount: 150.0,
        food: bread,
      );

      expect(logWithoutPortion.displayAmount, '150g');
    });
  });
}
