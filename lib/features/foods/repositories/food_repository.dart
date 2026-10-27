import 'package:sqflite/sqflite.dart';
import 'package:my_meal/core/database/database_helper.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';

class FoodRepository {
  final DatabaseHelper _dbHelper;

  FoodRepository({DatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<FoodItem>> getAllFoods({String? query}) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps;

    if (query != null && query.trim().isNotEmpty) {
      maps = await db.query(
        'foods',
        where: 'name LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: 'name ASC',
      );
    } else {
      maps = await db.query('foods', orderBy: 'name ASC');
    }

    return maps.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<FoodItem?> getFoodById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return FoodItem.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertFood(FoodItem food) async {
    final db = await _dbHelper.database;
    await db.insert('foods', food.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFoods(List<FoodItem> foods) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final food in foods) {
      batch.insert('foods', food.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateFood(FoodItem food) async {
    final db = await _dbHelper.database;
    await db.update(
      'foods',
      food.toMap(),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  Future<void> deleteFood(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Busca o alimento mais próximo a partir do nome falado no áudio
  Future<FoodItem?> findBestMatch(String spokenName) async {
    final allFoods = await getAllFoods();
    if (allFoods.isEmpty) return null;

    final normalizedSpoken = _normalizeText(spokenName);

    // 1. Match exato pelo nome do alimento
    for (final food in allFoods) {
      final normalizedFood = _normalizeText(food.name);
      if (normalizedFood == normalizedSpoken) {
        return food;
      }
    }

    // 2. Match exato ou parcial por nome de porção cadastrada
    for (final food in allFoods) {
      for (final portion in food.portions) {
        final normPortion = _normalizeText(portion.name);
        if (normPortion == normalizedSpoken || 
            normalizedSpoken.contains(normPortion) ||
            normPortion.contains(normalizedSpoken)) {
          return food;
        }
      }
    }

    // 3. Contém uma na outra no nome do alimento
    for (final food in allFoods) {
      final normalizedFood = _normalizeText(food.name);
      if (normalizedFood.contains(normalizedSpoken) || 
          normalizedSpoken.contains(normalizedFood)) {
        return food;
      }
    }

    // 4. Match por radicais / plural (ex: 'ovos' -> 'ovo', 'paes' -> 'pao')
    final spokenTokens = normalizedSpoken
        .split(' ')
        .map((w) => _stem(w))
        .where((w) => w.length >= 3)
        .toList();

    for (final food in allFoods) {
      final foodTokens = _normalizeText(food.name)
          .split(' ')
          .map((w) => _stem(w))
          .where((w) => w.length >= 3)
          .toList();

      final commonWords = spokenTokens.where((t) => foodTokens.contains(t)).toList();
      if (commonWords.isNotEmpty) {
        return food;
      }

      // Verifica também nas porções do alimento com radicais
      for (final portion in food.portions) {
        final portionTokens = _normalizeText(portion.name)
            .split(' ')
            .map((w) => _stem(w))
            .where((w) => w.length >= 3)
            .toList();
        final commonPortion = spokenTokens.where((t) => portionTokens.contains(t)).toList();
        if (commonPortion.isNotEmpty) {
          return food;
        }
      }
    }

    return null;
  }

  /// Identifica se o termo falado faz referência a uma porção específica do alimento
  FoodPortion? findMatchingPortion(FoodItem food, String spokenName) {
    if (food.portions.isEmpty) return null;

    final normSpoken = _normalizeText(spokenName);
    final spokenTokens = normSpoken.split(' ').map((w) => _stem(w)).toList();

    for (final portion in food.portions) {
      final normPortion = _normalizeText(portion.name);
      if (normSpoken.contains(normPortion) || normPortion.contains(normSpoken)) {
        return portion;
      }

      final portionTokens = normPortion.split(' ').map((w) => _stem(w)).where((w) => w.length >= 3).toList();
      final hasCommon = portionTokens.any((pt) => spokenTokens.contains(pt));
      if (hasCommon) {
        return portion;
      }
    }

    return null;
  }

  static String _stem(String word) {
    var w = word.trim().toLowerCase();
    if (w.endsWith('ões') || w.endsWith('oes')) {
      return '${w.substring(0, w.length - 3)}ao';
    }
    if (w.endsWith('ães') || w.endsWith('aes')) {
      return '${w.substring(0, w.length - 3)}ao';
    }
    if (w.endsWith('ns')) {
      return '${w.substring(0, w.length - 2)}m';
    }
    if (w.endsWith('is') && w.length > 3) {
      return '${w.substring(0, w.length - 2)}l';
    }
    if (w.endsWith('s') && w.length > 3) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  static String _normalizeText(String text) {
    var output = text.toLowerCase().trim();
    // Remover acentos comuns
    const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuuc';
    for (int i = 0; i < withAccents.length; i++) {
      output = output.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return output;
  }
}
