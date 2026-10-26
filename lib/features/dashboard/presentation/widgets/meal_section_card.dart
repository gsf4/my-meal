import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/presentation/screens/manual_add_meal_dialog.dart';
import 'package:my_meal/features/meals/presentation/widgets/clone_meal_sheet.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';

class MealSectionCard extends ConsumerWidget {
  final MealType mealType;
  final List<MealLog> logs;
  final DateTime selectedDate;

  const MealSectionCard({
    super.key,
    required this.mealType,
    required this.logs,
    required this.selectedDate,
  });

  void _openManualAdd(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ManualAddMealDialog(
        initialMealType: mealType,
        selectedDate: selectedDate,
      ),
    );

    if (result != null) {
      final food = result['food'] as FoodItem;
      final type = result['mealType'] as MealType;
      final amount = result['amount'] as double;

      await ref.read(mealLogsProvider.notifier).addMealLog(
        foodId: food.id,
        mealType: type,
        consumedAmount: amount,
        date: selectedDate,
        food: food,
      );
    }
  }

  void _openCloneSheet(BuildContext context) {
    CloneMealSheet.show(
      context,
      targetMealType: mealType,
      targetDate: selectedDate,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double totalCalories = 0.0;
    for (final log in logs) {
      totalCalories += log.calories;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _openCloneSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(mealType.icon, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    mealType.detailedLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${totalCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy_all_outlined, size: 20, color: Colors.grey),
                    tooltip: 'Copiar refeição de outro dia (ou segure no card)',
                    onPressed: () => _openCloneSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                    tooltip: 'Adicionar alimento',
                    onPressed: () => _openManualAdd(context, ref),
                  ),
                ],
              ),
              if (logs.isNotEmpty) ...[
                const Divider(height: 16),
                ...logs.map((log) {
                  final isPending = log.food?.isPendingNutrition ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.food?.name ?? 'Alimento',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${log.consumedAmount.toStringAsFixed(0)}g',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Pendente de dados',
                                        style: TextStyle(fontSize: 10, color: AppTheme.warningColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${log.calories.toStringAsFixed(0)} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () {
                            ref.read(mealLogsProvider.notifier).deleteMealLog(log.id);
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
