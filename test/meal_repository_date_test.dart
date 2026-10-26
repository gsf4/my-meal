import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/core/database/database_helper.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/repositories/meal_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MealRepository Date Resiliency Tests', () {
    late DatabaseHelper dbHelper;
    late MealRepository mealRepo;
    late FoodRepository foodRepo;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      mealRepo = MealRepository(dbHelper: dbHelper);
      foodRepo = FoodRepository(dbHelper: dbHelper);

      final db = await dbHelper.database;
      await db.delete('meal_logs');
    });

    test('getMealLogsByDate recupera registros gravados tanto em formato yyyy-MM-dd quanto ISO8601 completo', () async {
      final db = await dbHelper.database;
      final food = FoodItem(
        id: 'test-food-1',
        name: 'Arroz Teste',
        calories: 130,
        protein: 2.5,
        carbs: 28,
        fat: 0.3,
      );
      await foodRepo.insertFood(food);

      // Simula inserção legada com ISO8601 completo (como ocorria antes)
      await db.insert('meal_logs', {
        'id': 'legacy-log-1',
        'date': '2026-10-26T00:00:00.000',
        'meal_type': 'snack',
        'food_id': food.id,
        'consumed_amount': 150.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insere um log novo no formato padronizado yyyy-MM-dd
      final newLog = MealLog(
        id: 'new-log-1',
        date: DateTime(2026, 10, 26),
        mealType: MealType.snack,
        foodId: food.id,
        consumedAmount: 200.0,
      );
      await mealRepo.insertMealLog(newLog);

      // Busca pela data
      final logs = await mealRepo.getMealLogsByDate(DateTime(2026, 10, 26));

      expect(logs.length, 2);
      expect(logs.any((l) => l.id == 'legacy-log-1'), isTrue);
      expect(logs.any((l) => l.id == 'new-log-1'), isTrue);
    });
  });
}
