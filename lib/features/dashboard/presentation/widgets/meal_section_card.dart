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

  Future<void> _openEditAmountDialog(BuildContext context, WidgetRef ref, MealLog log) async {
    final food = log.food;
    final initialAmount = log.consumedAmount;
    final textController = TextEditingController(
      text: initialAmount % 1 == 0 
          ? initialAmount.toInt().toString() 
          : initialAmount.toString(),
    );

    double currentAmount = initialAmount;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewCalories = food?.calculateCalories(currentAmount) ?? 0.0;
            final previewProtein = food?.calculateProtein(currentAmount) ?? 0.0;
            final previewCarbs = food?.calculateCarbs(currentAmount) ?? 0.0;
            final previewFat = food?.calculateFat(currentAmount) ?? 0.0;

            return AlertDialog(
              title: const Text('Editar Quantidade'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food?.name ?? 'Alimento',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        suffixText: 'g',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                        setDialogState(() {
                          currentAmount = parsed;
                        });
                      },
                    ),
                    if (food != null && !food.isPendingNutrition) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Calorias:', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${previewCalories.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.caloriesColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(
                                  'P: ${previewProtein.toStringAsFixed(1)}g',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.proteinColor, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'C: ${previewCarbs.toStringAsFixed(1)}g',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.carbsColor, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'G: ${previewFat.toStringAsFixed(1)}g',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.fatColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newAmount = double.tryParse(textController.text.replaceAll(',', '.')) ?? 0.0;
                    if (newAmount > 0) {
                      Navigator.of(ctx).pop();
                      await ref.read(mealLogsProvider.notifier).updateConsumedAmount(log.id, newAmount);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Quantidade de "${food?.name ?? 'alimento'}" alterada para ${newAmount.toStringAsFixed(0)}g.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteLog(BuildContext context, WidgetRef ref, MealLog log) async {
    final foodName = log.food?.name ?? 'este alimento';
    final amountText = '${log.consumedAmount.toStringAsFixed(0)}g';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Alimento'),
        content: Text(
          'Deseja remover "$foodName" ($amountText) de ${mealType.detailedLabel}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(mealLogsProvider.notifier).deleteMealLog(log.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$foodName" foi removido de ${mealType.detailedLabel}.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openEditAmountDialog(context, ref, log),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit_outlined, size: 12, color: Colors.grey.shade500),
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
                            tooltip: 'Remover da refeição',
                            onPressed: () => _confirmDeleteLog(context, ref, log),
                          ),
                        ],
                      ),
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
