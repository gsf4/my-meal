import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
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

    // Normaliza registros legados no SQLite que possam ter sido gravados com timestamp completo
    try {
      await db.rawUpdate('UPDATE meal_logs SET date = substr(date, 1, 10) WHERE length(date) > 10');
    } catch (_) {}

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        ml.id AS ml_id,
        ml.date AS ml_date,
        ml.meal_type AS ml_meal_type,
        ml.food_id AS ml_food_id,
        ml.consumed_amount AS ml_consumed_amount,
        ml.portion_id AS ml_portion_id,
        ml.portion_name AS ml_portion_name,
        ml.portion_quantity AS ml_portion_quantity,
        ml.created_at AS ml_created_at,
        f.id AS f_id,
        f.name AS f_name,
        f.unit_type AS f_unit_type,
        f.calories AS f_calories,
        f.protein AS f_protein,
        f.carbs AS f_carbs,
        f.fat AS f_fat,
        f.is_pending_nutrition AS f_is_pending_nutrition,
        f.portions AS f_portions,
        f.created_at AS f_created_at
      FROM meal_logs ml
      LEFT JOIN foods f ON ml.food_id = f.id
      WHERE (ml.date = ? OR ml.date LIKE ? OR substr(ml.date, 1, 10) = ?)
      ORDER BY ml.created_at ASC
    ''', [formattedDate, '$formattedDate%', formattedDate]);

    return maps.map((row) {
      FoodItem? food;
      if (row['f_id'] != null) {
        food = FoodItem.fromMap({
          'id': row['f_id'],
          'name': row['f_name'],
          'unit_type': row['f_unit_type'],
          'calories': row['f_calories'],
          'protein': row['f_protein'],
          'carbs': row['f_carbs'],
          'fat': row['f_fat'],
          'is_pending_nutrition': row['f_is_pending_nutrition'],
          'portions': row['f_portions'],
          'created_at': row['f_created_at'],
        });
      }

      return MealLog(
        id: row['ml_id'] as String,
        date: DateTime.parse(row['ml_date'] as String),
        mealType: MealType.fromString(row['ml_meal_type'] as String),
        foodId: row['ml_food_id'] as String,
        consumedAmount: (row['ml_consumed_amount'] as num).toDouble(),
        portionId: row['ml_portion_id'] as String?,
        portionName: row['ml_portion_name'] as String?,
        portionQuantity: (row['ml_portion_quantity'] as num?)?.toDouble(),
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
        ml.portion_id AS ml_portion_id,
        ml.portion_name AS ml_portion_name,
        ml.portion_quantity AS ml_portion_quantity,
        ml.created_at AS ml_created_at,
        f.id AS f_id,
        f.name AS f_name,
        f.unit_type AS f_unit_type,
        f.calories AS f_calories,
        f.protein AS f_protein,
        f.carbs AS f_carbs,
        f.fat AS f_fat,
        f.is_pending_nutrition AS f_is_pending_nutrition,
        f.portions AS f_portions,
        f.created_at AS f_created_at
      FROM meal_logs ml
      LEFT JOIN foods f ON ml.food_id = f.id
      ORDER BY ml.date DESC, ml.created_at ASC
    ''');

    return maps.map((row) {
      FoodItem? food;
      if (row['f_id'] != null) {
        food = FoodItem.fromMap({
          'id': row['f_id'],
          'name': row['f_name'],
          'unit_type': row['f_unit_type'],
          'calories': row['f_calories'],
          'protein': row['f_protein'],
          'carbs': row['f_carbs'],
          'fat': row['f_fat'],
          'is_pending_nutrition': row['f_is_pending_nutrition'],
          'portions': row['f_portions'],
          'created_at': row['f_created_at'],
        });
      }

      return MealLog(
        id: row['ml_id'] as String,
        date: DateTime.parse(row['ml_date'] as String),
        mealType: MealType.fromString(row['ml_meal_type'] as String),
        foodId: row['ml_food_id'] as String,
        consumedAmount: (row['ml_consumed_amount'] as num).toDouble(),
        portionId: row['ml_portion_id'] as String?,
        portionName: row['ml_portion_name'] as String?,
        portionQuantity: (row['ml_portion_quantity'] as num?)?.toDouble(),
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

  Future<void> updateMealLogAmount(
    String id, 
    double newAmount, {
    double? newPortionQuantity,
  }) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> updateValues = {
      'consumed_amount': newAmount,
    };
    if (newPortionQuantity != null) {
      updateValues['portion_quantity'] = newPortionQuantity;
    }
    await db.update(
      'meal_logs',
      updateValues,
      where: 'id = ?',
      whereArgs: [id],
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

  /// Clona os alimentos de uma refeição para outra data e refeição
  Future<int> copyMealLogs({
    required DateTime sourceDate,
    required MealType sourceMealType,
    required DateTime targetDate,
    required MealType targetMealType,
  }) async {
    final sourceLogs = await getMealLogsByDate(sourceDate);
    final itemsToCopy = sourceLogs.where((l) => l.mealType == sourceMealType).toList();

    if (itemsToCopy.isEmpty) return 0;

    const uuid = Uuid();
    final now = DateTime.now();
    final List<MealLog> newLogs = [];

    for (final item in itemsToCopy) {
      newLogs.add(
        MealLog(
          id: uuid.v4(),
          date: targetDate,
          mealType: targetMealType,
          foodId: item.foodId,
          consumedAmount: item.consumedAmount,
          portionId: item.portionId,
          portionName: item.portionName,
          portionQuantity: item.portionQuantity,
          createdAt: now,
          food: item.food,
        ),
      );
    }

    await insertMealLogs(newLogs);
    return newLogs.length;
  }
}
