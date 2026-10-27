import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';
import 'package:my_meal/features/meal_planner/services/meal_plan_optimizer.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';

void main() {
  group('MealPlanOptimizer Unit Tests', () {
    late FoodItem eggFood;
    late FoodItem tapiocaFood;
    late FoodItem chickenFood;
    late FoodItem riceFood;

    setUp(() {
      eggFood = FoodItem(
        id: 'egg_1',
        name: 'Ovo Cozido Inteiro',
        unitType: FoodUnitType.per100g,
        calories: 146.0,
        protein: 13.3,
        carbs: 0.6,
        fat: 9.5,
        portions: [
          const FoodPortion(id: 'med', name: 'Ovo médio', grams: 55.0),
          const FoodPortion(id: 'gde', name: 'Ovo grande', grams: 65.0),
        ],
      );

      tapiocaFood = FoodItem(
        id: 'tapioca_1',
        name: 'Tapioca Goma',
        unitType: FoodUnitType.per100g,
        calories: 240.0,
        protein: 0.0,
        carbs: 60.0,
        fat: 0.0,
      );

      chickenFood = FoodItem(
        id: 'chicken_1',
        name: 'Peito de Frango Grelhado',
        unitType: FoodUnitType.per100g,
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
      );

      riceFood = FoodItem(
        id: 'rice_1',
        name: 'Arroz Branco Cozido',
        unitType: FoodUnitType.per100g,
        calories: 130.0,
        protein: 2.7,
        carbs: 28.2,
        fat: 0.3,
      );
    });

    test('Bate a meta de proteína com ovos médios e preenche o saldo com tapioca', () {
      final eggItem = VoiceDetectedFoodItem(
        spokenName: 'ovos médios',
        matchedFood: eggFood,
        grams: 55.0,
        portionId: 'med',
        portionName: 'Ovo médio',
        portionQuantity: 1.0,
      );

      final tapiocaItem = VoiceDetectedFoodItem(
        spokenName: 'goma de tapioca',
        matchedFood: tapiocaFood,
        grams: 50.0,
      );

      // Meta restante: 29g de proteína e 500 kcal
      final result = MealPlanOptimizer.optimize(
        items: [eggItem, tapiocaItem],
        targetCalories: 500.0,
        targetProtein: 29.0,
      );

      // Ovos médios fornecem ~7.315g de proteína por unidade
      // 4 ovos = ~29.26g de proteína
      final optEgg = result.items.firstWhere((it) => it.matchedFood?.id == 'egg_1');
      expect(optEgg.portionQuantity, 4.0);
      expect(optEgg.grams, 220.0);
      expect(optEgg.displayProtein, closeTo(29.26, 0.5));

      // Calorias dos 4 ovos = ~321 kcal
      // Restante para tapioca = 500 - 321 = ~179 kcal
      // Tapioca tem 2.4 kcal/g -> 179 / 2.4 = ~74.5g -> arredondado para 75g
      final optTapioca = result.items.firstWhere((it) => it.matchedFood?.id == 'tapioca_1');
      expect(optTapioca.grams, 75.0);
      expect(optTapioca.displayCalories, closeTo(180.0, 1.0));

      // Total planejado
      expect(result.totalProtein, greaterThanOrEqualTo(29.0));
      expect(result.totalCalories, closeTo(500.0, 25.0));
    });

    test('Bate a meta de proteína com peito de frango (em gramas) e preenche calorias com arroz', () {
      final chickenItem = VoiceDetectedFoodItem(
        spokenName: 'frango',
        matchedFood: chickenFood,
        grams: 100.0,
      );

      final riceItem = VoiceDetectedFoodItem(
        spokenName: 'arroz',
        matchedFood: riceFood,
        grams: 100.0,
      );

      // Meta restante: 45g de proteína e 600 kcal
      final result = MealPlanOptimizer.optimize(
        items: [chickenItem, riceItem],
        targetCalories: 600.0,
        targetProtein: 45.0,
      );

      final optChicken = result.items.firstWhere((it) => it.matchedFood?.id == 'chicken_1');
      // Frango tem 31g prot / 100g -> 45g prot precisa de ~145g frango
      expect(optChicken.grams, closeTo(145.0, 5.0));
      expect(optChicken.displayProtein, closeTo(45.0, 2.0));

      // Calorias do frango (~239 kcal) -> restam ~360 kcal para o arroz (~275g arroz)
      final optRice = result.items.firstWhere((it) => it.matchedFood?.id == 'rice_1');
      expect(optRice.grams, greaterThan(200.0));

      expect(result.totalProtein, greaterThanOrEqualTo(45.0));
      expect(result.totalCalories, closeTo(600.0, 30.0));
    });

    test('Quando a proteína já foi batida hoje (targetProtein = 0), distribui calorias suavemente', () {
      final eggItem = VoiceDetectedFoodItem(
        spokenName: 'ovos médios',
        matchedFood: eggFood,
        grams: 55.0,
        portionId: 'med',
        portionName: 'Ovo médio',
      );

      final tapiocaItem = VoiceDetectedFoodItem(
        spokenName: 'tapioca',
        matchedFood: tapiocaFood,
        grams: 50.0,
      );

      final result = MealPlanOptimizer.optimize(
        items: [eggItem, tapiocaItem],
        targetCalories: 350.0,
        targetProtein: 0.0,
      );

      expect(result.note, contains('Sua meta de proteína já foi batida hoje'));
      expect(result.totalCalories, greaterThan(0));
    });

    test('Quando o usuário fala apenas um alimento proteico', () {
      final eggItem = VoiceDetectedFoodItem(
        spokenName: 'ovos médios',
        matchedFood: eggFood,
        grams: 55.0,
        portionId: 'med',
        portionName: 'Ovo médio',
      );

      final result = MealPlanOptimizer.optimize(
        items: [eggItem],
        targetCalories: 400.0,
        targetProtein: 22.0,
      );

      // 22g de proteína = ~3 ovos médios
      expect(result.items.first.portionQuantity, 3.0);
      expect(result.items.first.grams, 165.0);
      expect(result.totalProtein, closeTo(22.0, 2.0));
    });
  });
}
