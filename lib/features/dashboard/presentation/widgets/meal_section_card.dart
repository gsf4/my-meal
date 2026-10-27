import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/presentation/screens/manual_add_meal_dialog.dart';
import 'package:my_meal/features/meals/presentation/widgets/clone_meal_sheet.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/meal_planner/presentation/widgets/plan_meal_dialog.dart';

class MealSectionCard extends ConsumerStatefulWidget {
  final MealType mealType;
  final List<MealLog> logs;
  final DateTime selectedDate;

  const MealSectionCard({
    super.key,
    required this.mealType,
    required this.logs,
    required this.selectedDate,
  });

  @override
  ConsumerState<MealSectionCard> createState() => _MealSectionCardState();
}

class _MealSectionCardState extends ConsumerState<MealSectionCard> {
  bool _isExpanded = false;

  void _openPlanMeal(BuildContext context) {
    PlanMealDialog.show(
      context,
      mealType: widget.mealType,
      targetDate: widget.selectedDate,
    );
  }

  void _openManualAdd(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ManualAddMealDialog(
        initialMealType: widget.mealType,
        selectedDate: widget.selectedDate,
      ),
    );

    if (result != null) {
      final food = result['food'] as FoodItem;
      final type = result['mealType'] as MealType;
      final amount = result['amount'] as double;
      final portionId = result['portionId'] as String?;
      final portionName = result['portionName'] as String?;
      final portionQuantity = result['portionQuantity'] as double?;

      await ref.read(mealLogsProvider.notifier).addMealLog(
        foodId: food.id,
        mealType: type,
        consumedAmount: amount,
        portionId: portionId,
        portionName: portionName,
        portionQuantity: portionQuantity,
        date: widget.selectedDate,
        food: food,
      );
    }
  }

  void _openCloneSheet(BuildContext context) {
    CloneMealSheet.show(
      context,
      targetMealType: widget.mealType,
      targetDate: widget.selectedDate,
    );
  }

  Future<void> _openEditAmountDialog(BuildContext context, MealLog log) async {
    final food = log.food;
    final isPortion = log.portionName != null && log.portionQuantity != null && log.portionQuantity! > 0;
    final portionUnitWeight = isPortion ? (log.consumedAmount / log.portionQuantity!) : 1.0;

    final initialCount = isPortion ? log.portionQuantity! : log.consumedAmount;
    final textController = TextEditingController(
      text: initialCount % 1 == 0 
          ? initialCount.toInt().toString() 
          : initialCount.toString(),
    );

    double currentAmount = log.consumedAmount;
    double currentPortionCount = isPortion ? log.portionQuantity! : 0.0;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewCalories = food?.calculateCalories(currentAmount) ?? 0.0;
            final previewProtein = food?.calculateProtein(currentAmount) ?? 0.0;
            final previewCarbs = food?.calculateCarbs(currentAmount) ?? 0.0;
            final previewFat = food?.calculateFat(currentAmount) ?? 0.0;

            final unitSuffix = food?.unitType.unitSuffix ?? 'g';
            final subtitleText = isPortion
                ? '${currentPortionCount % 1 == 0 ? currentPortionCount.toInt() : currentPortionCount}\u00D7 ${log.portionName} (${currentAmount % 1 == 0 ? currentAmount.toInt() : currentAmount.toStringAsFixed(1)}$unitSuffix)'
                : '${currentAmount % 1 == 0 ? currentAmount.toInt() : currentAmount.toStringAsFixed(1)}$unitSuffix';

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
                    if (isPortion)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 8),
                        child: Text(
                          'Medida: ${log.portionName} (${portionUnitWeight % 1 == 0 ? portionUnitWeight.toInt() : portionUnitWeight}$unitSuffix)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isPortion 
                            ? 'Quantidade de "${log.portionName}"'
                            : (food != null ? 'Quantidade (${food.unitType.label})' : 'Quantidade'),
                        suffixText: isPortion ? 'porção(ões)' : unitSuffix,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                        setDialogState(() {
                          if (isPortion) {
                            currentPortionCount = parsed;
                            currentAmount = parsed * portionUnitWeight;
                          } else {
                            currentAmount = parsed;
                          }
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
                                Text(subtitleText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                    final enteredVal = double.tryParse(textController.text.replaceAll(',', '.')) ?? 0.0;
                    if (enteredVal > 0) {
                      Navigator.of(ctx).pop();
                      final finalAmount = isPortion ? enteredVal * portionUnitWeight : enteredVal;
                      final finalPortionQty = isPortion ? enteredVal : null;

                      await ref.read(mealLogsProvider.notifier).updateConsumedAmount(
                        log.id, 
                        finalAmount,
                        newPortionQuantity: finalPortionQty,
                      );
                      if (context.mounted) {
                        final formattedNew = isPortion
                            ? '${enteredVal % 1 == 0 ? enteredVal.toInt() : enteredVal}\u00D7 ${log.portionName} (${finalAmount.toStringAsFixed(0)}$unitSuffix)'
                            : (food?.unitType.formatAmount(finalAmount) ?? '${finalAmount.toStringAsFixed(0)}g');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${food?.name ?? 'Alimento'}" atualizado para $formattedNew.'),
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

  Future<void> _confirmDeleteLog(BuildContext context, MealLog log) async {
    final foodName = log.food?.name ?? 'este alimento';
    final amountText = log.displayAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Alimento'),
        content: Text(
          'Deseja remover "$foodName" ($amountText) de ${widget.mealType.detailedLabel}?',
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
            content: Text('"$foodName" foi removido de ${widget.mealType.detailedLabel}.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final log in widget.logs) {
      totalCalories += log.calories;
      totalProtein += log.protein;
      totalCarbs += log.carbs;
      totalFat += log.fat;
    }

    final hasFoods = widget.logs.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // Header da Refeição (Clicável para expandir macros quando houver alimentos)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: hasFoods
                    ? () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      }
                    : null,
                onLongPress: () => _openCloneSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(widget.mealType.icon, color: AppTheme.primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.mealType.detailedLabel,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasFoods) ...[
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${totalCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        iconSize: 20,
                        icon: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                        tooltip: 'Planejar com IA',
                        onPressed: () => _openPlanMeal(context),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        iconSize: 22,
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                        tooltip: 'Adicionar alimento',
                        onPressed: () => _openManualAdd(context),
                      ),
                    ],
                  ),
                ),
              ),

              // Seção expansível com a quantidade de cada macronutriente na refeição
              if (hasFoods && _isExpanded) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroBadge(
                        label: 'Proteínas',
                        value: '${totalProtein.toStringAsFixed(1)}g',
                        color: AppTheme.proteinColor,
                        isDark: isDark,
                      ),
                      Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                      _buildMacroBadge(
                        label: 'Carboidratos',
                        value: '${totalCarbs.toStringAsFixed(1)}g',
                        color: AppTheme.carbsColor,
                        isDark: isDark,
                      ),
                      Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                      _buildMacroBadge(
                        label: 'Gorduras',
                        value: '${totalFat.toStringAsFixed(1)}g',
                        color: AppTheme.fatColor,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],

              // Estado Vazio: Atalho para planejar refeição com IA
              if (!hasFoods) ...[
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openPlanMeal(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: const Color(0xFF8B5CF6).withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Planejar ${widget.mealType.label.toLowerCase()} com IA por voz...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Lista de Alimentos
              if (hasFoods) ...[
                const Divider(height: 16),
                ...widget.logs.map((log) {
                  final isPending = log.food?.isPendingNutrition ?? false;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openEditAmountDialog(context, log),
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
                                    Flexible(
                                      child: Text(
                                        log.displayAmount,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                            onPressed: () => _confirmDeleteLog(context, log),
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

  Widget _buildMacroBadge({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
