import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/repositories/meal_repository.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';
import 'package:my_meal/features/settings/repositories/settings_repository.dart';

class BackupImportResult {
  final int foodsCount;
  final int mealLogsCount;
  final bool goalsUpdated;

  const BackupImportResult({
    required this.foodsCount,
    required this.mealLogsCount,
    required this.goalsUpdated,
  });
}

class BackupService {
  final FoodRepository _foodRepository;
  final MealRepository _mealRepository;
  final SettingsRepository _settingsRepository;

  BackupService({
    FoodRepository? foodRepository,
    MealRepository? mealRepository,
    SettingsRepository? settingsRepository,
  })  : _foodRepository = foodRepository ?? FoodRepository(),
        _mealRepository = mealRepository ?? MealRepository(),
        _settingsRepository = settingsRepository ?? SettingsRepository();

  /// 1. Exporta um backup completo em formato JSON (Lossless / Completo)
  Future<String> exportFullBackupJson() async {
    final foods = await _foodRepository.getAllFoods();
    final mealLogs = await _mealRepository.getAllMealLogs();
    final goals = await _settingsRepository.getDailyGoal();

    final backupData = {
      'app': 'My Meal',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'goals': {
        'calories': goals.calories,
        'protein': goals.protein,
        'carbs': goals.carbs,
        'fat': goals.fat,
      },
      'foods': foods.map((f) => f.toMap()).toList(),
      'meal_logs': mealLogs.map((m) => m.toMap()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/mymeal_backup_$timestamp.json');
    await file.writeAsString(jsonString, encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup My Meal ($timestamp)',
      ),
    );

    return file.path;
  }

  /// 2. Importa o backup completo a partir de uma string JSON
  Future<BackupImportResult> importBackupFromJson(String jsonContent) async {
    final Map<String, dynamic> data = jsonDecode(jsonContent);

    int importedFoods = 0;
    int importedLogs = 0;
    bool goalsUpdated = false;

    // Restaurar alimentos
    if (data['foods'] is List) {
      final List<FoodItem> foodsList = [];
      for (final item in data['foods']) {
        if (item is Map<String, dynamic>) {
          foodsList.add(FoodItem.fromMap(item));
        }
      }
      if (foodsList.isNotEmpty) {
        await _foodRepository.insertFoods(foodsList);
        importedFoods = foodsList.length;
      }
    }

    // Restaurar registros de refeição
    if (data['meal_logs'] is List) {
      final List<MealLog> logsList = [];
      for (final item in data['meal_logs']) {
        if (item is Map<String, dynamic>) {
          logsList.add(MealLog.fromMap(item));
        }
      }
      if (logsList.isNotEmpty) {
        await _mealRepository.insertMealLogs(logsList);
        importedLogs = logsList.length;
      }
    }

    // Restaurar metas diárias
    if (data['goals'] is Map<String, dynamic>) {
      final g = data['goals'] as Map<String, dynamic>;
      final goal = DailyGoal(
        calories: (g['calories'] as num?)?.toDouble() ?? 2000.0,
        protein: (g['protein'] as num?)?.toDouble() ?? 150.0,
        carbs: (g['carbs'] as num?)?.toDouble() ?? 200.0,
        fat: (g['fat'] as num?)?.toDouble() ?? 65.0,
      );
      await _settingsRepository.saveDailyGoal(goal);
      goalsUpdated = true;
    }

    return BackupImportResult(
      foodsCount: importedFoods,
      mealLogsCount: importedLogs,
      goalsUpdated: goalsUpdated,
    );
  }

  /// 3. Seleciona arquivo e restaura backup JSON
  Future<BackupImportResult?> pickAndImportJsonBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return null;
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    return await importBackupFromJson(content);
  }

  /// 4. Exporta histórico completo de refeições em Planilha CSV (Visualização Excel/Google Sheets)
  Future<String> exportMealsCsv() async {
    final mealLogs = await _mealRepository.getAllMealLogs();

    final buffer = StringBuffer();
    // Adicionar BOM UTF-8 (\uFEFF) para compatibilidade perfeita com Excel em português
    buffer.write('\uFEFF');

    // Cabeçalho compatível com Excel (delimitador ponto e vírgula)
    buffer.writeln('Data;Refeição;Alimento;Quantidade;Unidade;Porção;Calorias (kcal);Proteínas (g);Carboidratos (g);Gorduras (g)');

    final dateFormat = DateFormat('dd/MM/yyyy');

    for (final log in mealLogs) {
      final dateStr = dateFormat.format(log.date);
      final mealStr = log.mealType.label;
      final foodName = (log.food?.name ?? 'Desconhecido').replaceAll(';', ',');
      final amount = log.consumedAmount % 1 == 0 
          ? log.consumedAmount.toInt().toString() 
          : log.consumedAmount.toStringAsFixed(1);
      final unit = log.food?.unitType.unitSuffix ?? 'g';
      final portionInfo = log.portionName != null && log.portionQuantity != null
          ? '${log.portionQuantity! % 1 == 0 ? log.portionQuantity!.toInt() : log.portionQuantity}x ${log.portionName}' 
          : '';
      final cal = log.calories.toStringAsFixed(1);
      final prot = log.protein.toStringAsFixed(1);
      final carbs = log.carbs.toStringAsFixed(1);
      final fat = log.fat.toStringAsFixed(1);

      buffer.writeln('$dateStr;$mealStr;$foodName;$amount;$unit;$portionInfo;$cal;$prot;$carbs;$fat');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/mymeal_refeicoes_$timestamp.csv');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Planilha de Refeições My Meal ($timestamp)',
      ),
    );

    return file.path;
  }

  /// 5. Exporta o catálogo de alimentos em Planilha CSV
  Future<String> exportFoodsCsv() async {
    final foods = await _foodRepository.getAllFoods();

    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // BOM UTF-8

    buffer.writeln('Nome;Base;Porções;Calorias (kcal);Proteínas (g);Carboidratos (g);Gorduras (g);Status');

    for (final food in foods) {
      final name = food.name.replaceAll(';', ',');
      final unit = food.unitType.label;
      final portionsSummary = food.portions.map((p) => '${p.name} (${p.grams}g)').join(' | ').replaceAll(';', ',');
      final cal = food.calories.toStringAsFixed(1);
      final prot = food.protein.toStringAsFixed(1);
      final carbs = food.carbs.toStringAsFixed(1);
      final fat = food.fat.toStringAsFixed(1);
      final status = food.isPendingNutrition ? 'Pendente de Macros' : 'Completo';

      buffer.writeln('$name;$unit;$portionsSummary;$cal;$prot;$carbs;$fat;$status');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/mymeal_alimentos_$timestamp.csv');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Catálogo de Alimentos My Meal ($timestamp)',
      ),
    );

    return file.path;
  }

  /// 6. Importa lista de alimentos a partir de uma Planilha CSV
  Future<int> pickAndImportFoodsCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return 0;
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    if (lines.isEmpty) return 0;

    const uuid = Uuid();
    final List<FoodItem> importedFoods = [];

    // Ignora linha de cabeçalho
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Suporta separador ponto e vírgula (;) ou vírgula (,)
      final delimiter = line.contains(';') ? ';' : ',';
      final parts = line.split(delimiter);

      if (parts.isNotEmpty) {
        final name = parts[0].replaceAll('"', '').trim();
        if (name.isEmpty) continue;

        String unitTypeStr = 'per100g';
        double cal = 0.0;
        double prot = 0.0;
        double carbs = 0.0;
        double fat = 0.0;

        if (parts.length > 1) {
          unitTypeStr = parts[1].trim();
        }

        if (parts.length > 2) cal = double.tryParse(parts[2].trim().replaceAll(',', '.')) ?? 0.0;
        if (parts.length > 3) prot = double.tryParse(parts[3].trim().replaceAll(',', '.')) ?? 0.0;
        if (parts.length > 4) carbs = double.tryParse(parts[4].trim().replaceAll(',', '.')) ?? 0.0;
        if (parts.length > 5) fat = double.tryParse(parts[5].trim().replaceAll(',', '.')) ?? 0.0;

        importedFoods.add(
          FoodItem(
            id: uuid.v4(),
            name: name,
            unitType: FoodUnitType.fromString(unitTypeStr),
            calories: cal,
            protein: prot,
            carbs: carbs,
            fat: fat,
            isPendingNutrition: cal == 0 && prot == 0 && carbs == 0 && fat == 0,
          ),
        );
      }
    }

    if (importedFoods.isNotEmpty) {
      await _foodRepository.insertFoods(importedFoods);
    }

    return importedFoods.length;
  }
}
