import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  @visibleForTesting
  static void resetForTesting() {
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('my_meal.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Suporte para desktop (Windows/Linux/macOS) e testes
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        path = join(docDir.path, filePath);
      } catch (_) {
        // Fallback em ambiente headless de testes sem MethodChannel nativo
        path = inMemoryDatabasePath;
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de Alimentos
    await db.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit_type TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        is_pending_nutrition INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabela de Registros de Refeição
    await db.execute('''
      CREATE TABLE meal_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id TEXT NOT NULL,
        consumed_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES foods (id) ON DELETE CASCADE
      )
    ''');

    // Criar índice para busca rápida por data
    await db.execute('CREATE INDEX idx_meal_logs_date ON meal_logs(date)');
    await db.execute('CREATE INDEX idx_foods_name ON foods(name COLLATE NOCASE)');

    // Seed inicial com alimentos essenciais da culinária brasileira (Tabela TACO/IBGE)
    await _seedInitialFoods(db);
  }

  Future<void> _seedInitialFoods(Database db) async {
    final now = DateTime.now().toIso8601String();
    const uuid = Uuid();

    final initialFoods = [
      {'name': 'Arroz Branco Cozido', 'unit_type': 'per100g', 'calories': 128.0, 'protein': 2.5, 'carbs': 28.1, 'fat': 0.2},
      {'name': 'Arroz Integral Cozido', 'unit_type': 'per100g', 'calories': 124.0, 'protein': 2.6, 'carbs': 25.8, 'fat': 1.0},
      {'name': 'Feijão Carioca Cozido', 'unit_type': 'per100g', 'calories': 76.0, 'protein': 4.8, 'carbs': 13.6, 'fat': 0.5},
      {'name': 'Feijão Preto Cozido', 'unit_type': 'per100g', 'calories': 77.0, 'protein': 4.5, 'carbs': 14.0, 'fat': 0.5},
      {'name': 'Peito de Frango Grelhado', 'unit_type': 'per100g', 'calories': 159.0, 'protein': 32.0, 'carbs': 0.0, 'fat': 2.5},
      {'name': 'Patinho Moído Cozido', 'unit_type': 'per100g', 'calories': 219.0, 'protein': 35.9, 'carbs': 0.0, 'fat': 7.3},
      {'name': 'Ovo Cozido Inteiro', 'unit_type': 'per100g', 'calories': 146.0, 'protein': 13.3, 'carbs': 0.6, 'fat': 9.5},
      {'name': 'Ovo Frito', 'unit_type': 'per100g', 'calories': 240.0, 'protein': 15.6, 'carbs': 1.2, 'fat': 18.6},
      {'name': 'Aveia em Flocos', 'unit_type': 'per100g', 'calories': 394.0, 'protein': 13.9, 'carbs': 66.6, 'fat': 8.5},
      {'name': 'Banana Prata', 'unit_type': 'per100g', 'calories': 98.0, 'protein': 1.3, 'carbs': 26.0, 'fat': 0.1},
      {'name': 'Maçã Fuji com Casca', 'unit_type': 'per100g', 'calories': 56.0, 'protein': 0.3, 'carbs': 15.2, 'fat': 0.2},
      {'name': 'Pão Francês', 'unit_type': 'per100g', 'calories': 300.0, 'protein': 8.0, 'carbs': 58.6, 'fat': 3.1},
      {'name': 'Azeite de Oliva Extra Virgem', 'unit_type': 'per100g', 'calories': 884.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 100.0},
      {'name': 'Leite Desnatado', 'unit_type': 'per100g', 'calories': 35.0, 'protein': 3.4, 'carbs': 4.9, 'fat': 0.1},
      {'name': 'Leite Integral', 'unit_type': 'per100g', 'calories': 61.0, 'protein': 3.2, 'carbs': 4.8, 'fat': 3.2},
      {'name': 'Batata Doce Cozida', 'unit_type': 'per100g', 'calories': 77.0, 'protein': 0.6, 'carbs': 18.4, 'fat': 0.1},
      {'name': 'Batata Inglesa Cozida', 'unit_type': 'per100g', 'calories': 52.0, 'protein': 1.2, 'carbs': 11.9, 'fat': 0.1},
      {'name': 'Whey Protein Concentrado 80%', 'unit_type': 'per100g', 'calories': 400.0, 'protein': 80.0, 'carbs': 6.0, 'fat': 6.0},
      {'name': 'Tapioca Goma', 'unit_type': 'per100g', 'calories': 240.0, 'protein': 0.0, 'carbs': 60.0, 'fat': 0.0},
      {'name': 'Queijo Minas Frescal', 'unit_type': 'per100g', 'calories': 227.0, 'protein': 16.0, 'carbs': 3.2, 'fat': 16.0},
    ];

    final batch = db.batch();
    for (final food in initialFoods) {
      batch.insert('foods', {
        'id': uuid.v4(),
        'name': food['name'],
        'unit_type': food['unit_type'],
        'calories': food['calories'],
        'protein': food['protein'],
        'carbs': food['carbs'],
        'fat': food['fat'],
        'is_pending_nutrition': 0,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
