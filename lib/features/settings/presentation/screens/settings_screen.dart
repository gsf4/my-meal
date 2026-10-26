import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/constants/app_constants.dart';
import 'package:my_meal/core/theme/app_theme.dart';
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
                        const SizedBox(width: 8),
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
