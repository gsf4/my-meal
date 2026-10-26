import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/dashboard/presentation/widgets/calorie_ring.dart';
import 'package:my_meal/features/dashboard/presentation/widgets/macro_progress_bar.dart';
import 'package:my_meal/features/dashboard/presentation/widgets/meal_section_card.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/settings/providers/settings_providers.dart';
import 'package:my_meal/features/voice_logging/presentation/widgets/voice_record_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Hoje';
    if (target == today.subtract(const Duration(days: 1))) return 'Ontem';
    if (target == today.add(const Duration(days: 1))) return 'Amanhã';

    return DateFormat('EEE, d \'de\' MMMM', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final progress = ref.watch(nutritionProgressProvider);
    final logsAsync = ref.watch(mealLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Ir para hoje',
            onPressed: () {
              ref.read(selectedDateProvider.notifier).goToToday();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seletor de Data (< Ontem | Hoje | Amanhã >)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      ref.read(selectedDateProvider.notifier).previousDay();
                    },
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        ref.read(selectedDateProvider.notifier).setDate(picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateHeader(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      ref.read(selectedDateProvider.notifier).nextDay();
                    },
                  ),
                ],
              ),
            ),

            // Card Resumo de Calorias
            CalorieSummaryCard(
              goal: progress.goal.calories,
              consumed: progress.consumed.calories,
            ),
            const SizedBox(height: 12),

            // Card Progresso de Macronutrientes
            MacroProgressCard(
              currentProtein: progress.consumed.protein,
              goalProtein: progress.goal.protein,
              currentCarbs: progress.consumed.carbs,
              goalCarbs: progress.goal.carbs,
              currentFat: progress.consumed.fat,
              goalFat: progress.goal.fat,
            ),
            const SizedBox(height: 16),

            // Seções de Refeições
            logsAsync.when(
              data: (logs) {
                final Map<MealType, List<MealLog>> grouped = {
                  for (final type in MealType.values) type: <MealLog>[],
                };

                for (final log in logs) {
                  grouped[log.mealType]?.add(log);
                }

                return Column(
                  children: MealType.values.map((type) {
                    return MealSectionCard(
                      mealType: type,
                      logs: grouped[type] ?? [],
                      selectedDate: selectedDate,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Erro ao carregar registros: $err'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const VoiceRecordButton(),
    );
  }
}
