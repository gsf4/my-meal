import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/providers/food_providers.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/settings/models/daily_goal.dart';
import 'package:my_meal/features/settings/providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _calController = TextEditingController();
  final _protController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _obscureApiKey = true;
  bool _isInitialized = false;
  bool _isLoadingBackup = false;

  @override
  void dispose() {
    _calController.dispose();
    _protController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _loadValues(DailyGoal goal, String apiKey) {
    if (_isInitialized) return;
    _calController.text = goal.calories.toStringAsFixed(0);
    _protController.text = goal.protein.toStringAsFixed(0);
    _carbsController.text = goal.carbs.toStringAsFixed(0);
    _fatController.text = goal.fat.toStringAsFixed(0);
    _apiKeyController.text = apiKey;
    _isInitialized = true;
  }

  Future<void> _saveGoals() async {
    final calories = double.tryParse(_calController.text) ?? AppConstants.defaultCalories;
    final protein = double.tryParse(_protController.text) ?? AppConstants.defaultProtein;
    final carbs = double.tryParse(_carbsController.text) ?? AppConstants.defaultCarbs;
    final fat = double.tryParse(_fatController.text) ?? AppConstants.defaultFat;

    final newGoal = DailyGoal(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    await ref.read(dailyGoalProvider.notifier).updateGoal(newGoal);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metas diárias salvas com sucesso!'),
          backgroundColor: AppTheme.caloriesColor,
        ),
      );
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await ref.read(geminiApiKeyProvider.notifier).updateApiKey(key);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chave do Google Gemini salva com sucesso!'),
          backgroundColor: AppTheme.caloriesColor,
        ),
      );
    }
  }

  void _restoreDefaultGoals() {
    setState(() {
      _calController.text = AppConstants.defaultCalories.toStringAsFixed(0);
      _protController.text = AppConstants.defaultProtein.toStringAsFixed(0);
      _carbsController.text = AppConstants.defaultCarbs.toStringAsFixed(0);
      _fatController.text = AppConstants.defaultFat.toStringAsFixed(0);
    });
    _saveGoals();
  }

  Future<void> _exportFullBackup() async {
    setState(() => _isLoadingBackup = true);
    try {
      final path = await ref.read(backupServiceProvider).exportFullBackupJson();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup exportado com sucesso: ${path.split(RegExp(r'[/\\]')).last}'),
            backgroundColor: AppTheme.caloriesColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar backup: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackup = false);
    }
  }

  Future<void> _restoreFullBackup() async {
    setState(() => _isLoadingBackup = true);
    try {
      final result = await ref.read(backupServiceProvider).pickAndImportJsonBackup();
      if (result != null) {
        // Atualizar estado reativo dos alimentos, logs e metas
        await ref.read(foodListProvider.notifier).loadFoods();
        await ref.read(mealLogsProvider.notifier).loadLogs();
        await ref.read(dailyGoalProvider.notifier).loadGoal();

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.caloriesColor),
                  SizedBox(width: 8),
                  Text('Backup Restaurado'),
                ],
              ),
              content: Text(
                'Sucesso! Foram restaurados:\n\n'
                '• ${result.foodsCount} alimentos no catálogo\n'
                '• ${result.mealLogsCount} registros de refeições\n'
                '${result.goalsUpdated ? '• Metas diárias atualizadas\n' : ''}',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao restaurar backup: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackup = false);
    }
  }

  Future<void> _exportMealsCsv() async {
    setState(() => _isLoadingBackup = true);
    try {
      final path = await ref.read(backupServiceProvider).exportMealsCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planilha de refeições pronta: ${path.split(RegExp(r'[/\\]')).last}'),
            backgroundColor: AppTheme.caloriesColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar planilha: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackup = false);
    }
  }

  Future<void> _exportFoodsCsv() async {
    setState(() => _isLoadingBackup = true);
    try {
      final path = await ref.read(backupServiceProvider).exportFoodsCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planilha de alimentos pronta: ${path.split(RegExp(r'[/\\]')).last}'),
            backgroundColor: AppTheme.caloriesColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar alimentos: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackup = false);
    }
  }

  Future<void> _importFoodsCsv() async {
    setState(() => _isLoadingBackup = true);
    try {
      final count = await ref.read(backupServiceProvider).pickAndImportFoodsCsv();
      if (count > 0) {
        await ref.read(foodListProvider.notifier).loadFoods();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count alimentos importados com sucesso!'),
              backgroundColor: AppTheme.caloriesColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar planilha: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(dailyGoalProvider);
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);

    final goal = goalAsync.value ?? DailyGoal.defaultGoal();
    final apiKey = apiKeyAsync.value ?? '';
    _loadValues(goal, apiKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção de IA / Gemini API Key
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Google Gemini API Key',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Necessária para habilitar o registro de refeições por voz. '
                      'Você pode obter sua chave gratuitamente no Google AI Studio (aistudio.google.com).',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'Chave de API do Gemini',
                        hintText: 'AIzaSy...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscureApiKey = !_obscureApiKey);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _saveApiKey,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar Chave'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Seção de Metas Diárias
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.track_changes, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        const Text(
                          'Metas Diárias',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _restoreDefaultGoals,
                          child: const Text('Padrão', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Defina seus alvos diários de calorias e macronutrientes para acompanhar seu progresso diário.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _calController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Meta de Calorias (kcal)',
                        prefixIcon: Icon(Icons.local_fire_department, color: AppTheme.caloriesColor),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _protController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Proteínas (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _carbsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Carboidratos (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Gorduras (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _saveGoals,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar Metas'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nova Seção: Backup & Exportação de Dados
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.backup_outlined, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Backup e Exportação de Dados',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Como seus dados ficam salvos apenas neste aparelho, use as opções abaixo para fazer backup de segurança ou visualizar suas refeições no Excel / Google Sheets.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    if (_isLoadingBackup)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      // Backup Completo (JSON)
                      const Text(
                        'Backup do Aplicativo (Completo)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportFullBackup,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Exportar Backup'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _restoreFullBackup,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Restaurar Backup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Planilhas Excel / CSV
                      const Text(
                        'Visualização em Planilhas (Excel / Sheets)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.caloriesColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.table_chart_outlined, color: AppTheme.caloriesColor),
                        ),
                        title: const Text('Exportar Histórico de Refeições (CSV)'),
                        subtitle: const Text('Gera planilha com data, refeição, gramas, calorias e macros.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportMealsCsv,
                      ),
                      const Divider(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.carbsColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu_outlined, color: AppTheme.carbsColor),
                        ),
                        title: const Text('Exportar Catálogo de Alimentos (CSV)'),
                        subtitle: const Text('Gera planilha com todos os alimentos e valores por 100g.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportFoodsCsv,
                      ),
                      const Divider(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.file_upload_outlined, color: AppTheme.primaryColor),
                        ),
                        title: const Text('Importar Alimentos por Planilha (CSV)'),
                        subtitle: const Text('Adiciona novos alimentos em lote a partir de um arquivo CSV.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _importFoodsCsv,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Informações do App
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sobre o My Meal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aplicativo offline-first para rastreamento de calorias e macronutrientes com inteligência artificial multimodal Google Gemini.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Versão: 1.0.0 (MVP)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
