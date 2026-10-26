import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';

class CloneMealSheet extends ConsumerStatefulWidget {
  final MealType targetMealType;
  final DateTime targetDate;

  const CloneMealSheet({
    super.key,
    required this.targetMealType,
    required this.targetDate,
  });

  static Future<void> show(BuildContext context, {
    required MealType targetMealType,
    required DateTime targetDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CloneMealSheet(
        targetMealType: targetMealType,
        targetDate: targetDate,
      ),
    );
  }

  @override
  ConsumerState<CloneMealSheet> createState() => _CloneMealSheetState();
}

class _CloneMealSheetState extends ConsumerState<CloneMealSheet> {
  bool _showCustomSelector = false;
  late DateTime _selectedSourceDate;
  late MealType _selectedSourceMealType;
  bool _isCloning = false;

  @override
  void initState() {
    super.initState();
    // Padrão para seleção customizada: ontem e a mesma refeição
    _selectedSourceDate = widget.targetDate.subtract(const Duration(days: 1));
    _selectedSourceMealType = widget.targetMealType;
  }

  Future<void> _cloneFromYesterdaySameMeal() async {
    final yesterday = widget.targetDate.subtract(const Duration(days: 1));
    setState(() => _isCloning = true);

    try {
      final count = await ref.read(mealLogsProvider.notifier).cloneMeal(
        sourceDate: yesterday,
        sourceMealType: widget.targetMealType,
        targetDate: widget.targetDate,
        targetMealType: widget.targetMealType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count alimento(s) clonado(s) do ${widget.targetMealType.detailedLabel} de ontem!'),
              backgroundColor: AppTheme.caloriesColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nenhum alimento registrado no ${widget.targetMealType.detailedLabel} de ontem.'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  Future<void> _cloneFromCustomSelection() async {
    setState(() => _isCloning = true);

    try {
      final count = await ref.read(mealLogsProvider.notifier).cloneMeal(
        sourceDate: _selectedSourceDate,
        sourceMealType: _selectedSourceMealType,
        targetDate: widget.targetDate,
        targetMealType: widget.targetMealType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final dateFormatted = DateFormat('dd/MM').format(_selectedSourceDate);
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count alimento(s) copiado(s) de ${_selectedSourceMealType.detailedLabel} ($dateFormatted)!'),
              backgroundColor: AppTheme.caloriesColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nenhum alimento encontrado em ${_selectedSourceMealType.detailedLabel} de $dateFormatted.'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yesterday = widget.targetDate.subtract(const Duration(days: 1));
    final yesterdayFormatted = DateFormat("dd/MM (EEEE)", "pt_BR").format(yesterday);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.copy_all, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Copiar para ${widget.targetMealType.detailedLabel}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Copie alimentos de dias anteriores sem precisar digitar tudo novamente.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          if (_isCloning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_showCustomSelector) ...[
            // Opção 1: Mesma refeição de ontem
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.caloriesColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: AppTheme.caloriesColor),
                ),
                title: const Text('Clonar da mesma refeição de ontem', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Copiar do ${widget.targetMealType.detailedLabel} de $yesterdayFormatted'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _cloneFromYesterdaySameMeal,
              ),
            ),
            const SizedBox(height: 10),

            // Opção 2: De outra refeição ou data
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune, color: AppTheme.primaryColor),
                ),
                title: const Text('Clonar de outra refeição ou data...', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Escolher qual dia e qual refeição deseja copiar'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() => _showCustomSelector = true);
                },
              ),
            ),
          ] else ...[
            // Formulário de Seleção Customizada
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. De qual data deseja copiar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedSourceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _selectedSourceDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat("dd/MM/yyyy (EEEE)", "pt_BR").format(_selectedSourceDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Text('Alterar', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('2. De qual refeição dessa data?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MealType>(
                    initialValue: _selectedSourceMealType,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: MealType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(type.detailedLabel),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSourceMealType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showCustomSelector = false),
                        child: const Text('Voltar'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _cloneFromCustomSelection,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Itens'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
