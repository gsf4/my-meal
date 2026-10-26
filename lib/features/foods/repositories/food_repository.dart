import 'package:my_meal/core/database/database_helper.dart';
import 'package:my_meal/features/foods/models/food_item.dart';

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
    await db.insert('foods', food.toMap());
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

    // 1. Match exato
    for (final food in allFoods) {
      final normalizedFood = _normalizeText(food.name);
      if (normalizedFood == normalizedSpoken) {
        return food;
      }
    }

    // 2. Contém uma na outra
    for (final food in allFoods) {
      final normalizedFood = _normalizeText(food.name);
      if (normalizedFood.contains(normalizedSpoken) || 
          normalizedSpoken.contains(normalizedFood)) {
        return food;
      }
    }

    // 3. Match por palavras-chave principais (ex: 'arroz', 'frango', 'ovo')
    final spokenTokens = normalizedSpoken.split(' ').where((w) => w.length > 2).toList();
    for (final food in allFoods) {
      final foodTokens = _normalizeText(food.name).split(' ').where((w) => w.length > 2).toList();
      final commonWords = spokenTokens.where((t) => foodTokens.contains(t)).toList();
      if (commonWords.isNotEmpty) {
        return food;
      }
    }

    return null;
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
