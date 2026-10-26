import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:my_meal/core/database/database_helper.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';

class MealRepository {
  final DatabaseHelper _dbHelper;

  MealRepository({DatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<List<MealLog>> getMealLogsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final formattedDate = _formatDate(date);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        ml.id AS ml_id,
        ml.date AS ml_date,
        ml.meal_type AS ml_meal_type,
        ml.food_id AS ml_food_id,
        ml.consumed_amount AS ml_consumed_amount,
        ml.created_at AS ml_created_at,
        f.id AS f_id,
        f.name AS f_name,
        f.unit_type AS f_unit_type,
        f.calories AS f_calories,
        f.protein AS f_protein,
        f.carbs AS f_carbs,
        f.fat AS f_fat,
        f.is_pending_nutrition AS f_is_pending_nutrition,
        f.created_at AS f_created_at
      FROM meal_logs ml
      LEFT JOIN foods f ON ml.food_id = f.id
      WHERE ml.date = ?
      ORDER BY ml.created_at ASC
    ''', [formattedDate]);

    return maps.map((row) {
      FoodItem? food;
      if (row['f_id'] != null) {
        food = FoodItem(
          id: row['f_id'] as String,
          name: row['f_name'] as String,
          unitType: FoodUnitType.fromString(row['f_unit_type'] as String? ?? 'per100g'),
          calories: (row['f_calories'] as num?)?.toDouble() ?? 0.0,
          protein: (row['f_protein'] as num?)?.toDouble() ?? 0.0,
          carbs: (row['f_carbs'] as num?)?.toDouble() ?? 0.0,
          fat: (row['f_fat'] as num?)?.toDouble() ?? 0.0,
          isPendingNutrition: (row['f_is_pending_nutrition'] as int? ?? 0) == 1,
          createdAt: row['f_created_at'] != null 
              ? DateTime.parse(row['f_created_at'] as String) 
              : DateTime.now(),
        );
      }

      return MealLog(
        id: row['ml_id'] as String,
        date: DateTime.parse(row['ml_date'] as String),
        mealType: MealType.fromString(row['ml_meal_type'] as String),
        foodId: row['ml_food_id'] as String,
        consumedAmount: (row['ml_consumed_amount'] as num).toDouble(),
        createdAt: DateTime.parse(row['ml_created_at'] as String),
        food: food,
      );
    }).toList();
  }

  Future<List<MealLog>> getAllMealLogs() async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        ml.id AS ml_id,
        ml.date AS ml_date,
        ml.meal_type AS ml_meal_type,
        ml.food_id AS ml_food_id,
        ml.consumed_amount AS ml_consumed_amount,
        ml.created_at AS ml_created_at,
        f.id AS f_id,
        f.name AS f_name,
        f.unit_type AS f_unit_type,
        f.calories AS f_calories,
        f.protein AS f_protein,
        f.carbs AS f_carbs,
        f.fat AS f_fat,
        f.is_pending_nutrition AS f_is_pending_nutrition,
        f.created_at AS f_created_at
      FROM meal_logs ml
      LEFT JOIN foods f ON ml.food_id = f.id
      ORDER BY ml.date DESC, ml.created_at ASC
    ''');

    return maps.map((row) {
      FoodItem? food;
      if (row['f_id'] != null) {
        food = FoodItem(
          id: row['f_id'] as String,
          name: row['f_name'] as String,
          unitType: FoodUnitType.fromString(row['f_unit_type'] as String? ?? 'per100g'),
          calories: (row['f_calories'] as num?)?.toDouble() ?? 0.0,
          protein: (row['f_protein'] as num?)?.toDouble() ?? 0.0,
          carbs: (row['f_carbs'] as num?)?.toDouble() ?? 0.0,
          fat: (row['f_fat'] as num?)?.toDouble() ?? 0.0,
          isPendingNutrition: (row['f_is_pending_nutrition'] as int? ?? 0) == 1,
          createdAt: row['f_created_at'] != null 
              ? DateTime.parse(row['f_created_at'] as String) 
              : DateTime.now(),
        );
      }

      return MealLog(
        id: row['ml_id'] as String,
        date: DateTime.parse(row['ml_date'] as String),
        mealType: MealType.fromString(row['ml_meal_type'] as String),
        foodId: row['ml_food_id'] as String,
        consumedAmount: (row['ml_consumed_amount'] as num).toDouble(),
        createdAt: DateTime.parse(row['ml_created_at'] as String),
        food: food,
      );
    }).toList();
  }

  Future<void> insertMealLog(MealLog log) async {
    final db = await _dbHelper.database;
    await db.insert('meal_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertMealLogs(List<MealLog> logs) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert('meal_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMealLog(MealLog log) async {
    final db = await _dbHelper.database;
    await db.update(
      'meal_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deleteMealLog(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'meal_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
