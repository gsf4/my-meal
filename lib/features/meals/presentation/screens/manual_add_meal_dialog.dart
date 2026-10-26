import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';
import 'package:my_meal/features/foods/presentation/screens/food_form_dialog.dart';
import 'package:my_meal/features/foods/providers/food_providers.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';

class ManualAddMealDialog extends ConsumerStatefulWidget {
  final MealType initialMealType;
  final DateTime selectedDate;

  const ManualAddMealDialog({
    super.key,
    required this.initialMealType,
    required this.selectedDate,
  });

  @override
  ConsumerState<ManualAddMealDialog> createState() => _ManualAddMealDialogState();
}

class _ManualAddMealDialogState extends ConsumerState<ManualAddMealDialog> {
  late MealType _mealType;
  FoodItem? _selectedFood;
  FoodPortion? _selectedPortion;
  final _amountController = TextEditingController(text: '100');
  final _portionCountController = TextEditingController(text: '1');
  final _searchController = TextEditingController();
  List<FoodItem> _filteredFoods = [];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _portionCountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFoodSelected(FoodItem food) {
    setState(() {
      _selectedFood = food;
      _selectedPortion = food.portions.isNotEmpty ? food.portions.first : null;
      _portionCountController.text = '1';
      if (food.unitType == FoodUnitType.unit || food.unitType == FoodUnitType.slice) {
        _amountController.text = '1';
      } else {
        _amountController.text = '100';
      }
    });
  }

  void _createNewFood() async {
    final newFood = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => FoodFormDialog(initialName: _searchController.text),
    );

    if (newFood != null) {
      await ref.read(foodListProvider.notifier).addFood(newFood);
      _onFoodSelected(newFood);
    }
  }

  void _submit() {
    if (_selectedFood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um alimento da lista')),
      );
      return;
    }

    if (_selectedPortion != null) {
      final count = double.tryParse(_portionCountController.text.replaceAll(',', '.')) ?? 0.0;
      if (count <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe uma quantidade válida de porções')),
        );
        return;
      }

      final effectiveAmount = count * _selectedPortion!.grams;
      Navigator.of(context).pop({
        'food': _selectedFood,
        'mealType': _mealType,
        'amount': effectiveAmount,
        'portionId': _selectedPortion!.id,
        'portionName': _selectedPortion!.name,
        'portionQuantity': count,
      });
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida')),
      );
      return;
    }

    Navigator.of(context).pop({
      'food': _selectedFood,
      'mealType': _mealType,
      'amount': amount,
      'portionId': null,
      'portionName': null,
      'portionQuantity': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registrar Alimento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Seletor de Tipo de Refeição
              DropdownButtonFormField<MealType>(
                initialValue: _mealType,
                decoration: const InputDecoration(
                  labelText: 'Refeição',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: MealType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 20, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(type.detailedLabel),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _mealType = val);
                },
              ),
              const SizedBox(height: 12),
              // Alimento selecionado ou Campo de busca
              if (_selectedFood != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFood!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '${_selectedFood!.calories.toStringAsFixed(0)} kcal (${_selectedFood!.unitType.label})',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.change_circle_outlined, color: AppTheme.primaryColor),
                        tooltip: 'Trocar alimento',
                        onPressed: () => setState(() => _selectedFood = null),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar alimento no catálogo...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Novo', style: TextStyle(fontSize: 12)),
                      onPressed: _createNewFood,
                    ),
                  ),
                  onChanged: (query) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: foodsAsync.when(
                    data: (foods) {
                      final query = _searchController.text.toLowerCase().trim();
                      _filteredFoods = query.isEmpty
                          ? foods
                          : foods.where((f) => f.name.toLowerCase().contains(query)).toList();

                      if (_filteredFoods.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Nenhum alimento encontrado.'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createNewFood,
                                icon: const Icon(Icons.add),
                                label: const Text('Cadastrar este alimento'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: _filteredFoods.length,
                        itemBuilder: (context, index) {
                          final food = _filteredFoods[index];
                          return ListTile(
                            dense: true,
                            title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('${food.calories.toStringAsFixed(0)} kcal (${food.unitType.label})${food.portions.isNotEmpty ? " • ${food.portions.length} porções" : ""}'),
                            trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                            onTap: () => _onFoodSelected(food),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Erro: $err')),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Seletor de Medida / Porção ou Quantidade Direta
              if (_selectedFood != null && _selectedFood!.portions.isNotEmpty) ...[
                DropdownButtonFormField<FoodPortion?>(
                  key: ValueKey('${_selectedFood?.id}_${_selectedPortion?.id}'),
                  initialValue: _selectedPortion,
                  decoration: const InputDecoration(
                    labelText: 'Como deseja medir? *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    ..._selectedFood!.portions.map((portion) {
                      return DropdownMenuItem<FoodPortion?>(
                        value: portion,
                        child: Text(
                          '${portion.name} (${portion.grams % 1 == 0 ? portion.grams.toInt() : portion.grams}${_selectedFood!.unitType.unitSuffix})',
                        ),
                      );
                    }),
                    DropdownMenuItem<FoodPortion?>(
                      value: null,
                      child: Text('Quantidade personalizada (${_selectedFood!.unitType.unitSuffix})'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedPortion = val;
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Campo de entrada da quantidade
              if (_selectedPortion != null) ...[
                TextField(
                  controller: _portionCountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantidade de "${_selectedPortion!.name}"',
                    suffixText: 'porção(ões)',
                    hintText: 'Ex: 2',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedFood != null 
                        ? 'Quantidade consumida (${_selectedFood!.unitType.label})'
                        : 'Quantidade consumida',
                    suffixText: _selectedFood?.unitType.unitSuffix ?? 'g',
                    hintText: _selectedFood?.unitType == FoodUnitType.unit || _selectedFood?.unitType == FoodUnitType.slice
                        ? 'Ex: 2'
                        : 'Ex: 100',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              // Card de Pré-visualização Nutricional Instantânea
              if (_selectedFood != null) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final double effectiveGrams;
                    final String displaySubtitle;

                    if (_selectedPortion != null) {
                      final count = double.tryParse(_portionCountController.text.replaceAll(',', '.')) ?? 0.0;
                      effectiveGrams = count * _selectedPortion!.grams;
                      final countStr = count % 1 == 0 ? count.toInt().toString() : count.toStringAsFixed(1);
                      final gramsStr = effectiveGrams % 1 == 0 ? effectiveGrams.toInt().toString() : effectiveGrams.toStringAsFixed(1);
                      displaySubtitle = '$countStr\u00D7 ${_selectedPortion!.name} = $gramsStr${_selectedFood!.unitType.unitSuffix}';
                    } else {
                      effectiveGrams = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
                      final gramsStr = effectiveGrams % 1 == 0 ? effectiveGrams.toInt().toString() : effectiveGrams.toStringAsFixed(1);
                      displaySubtitle = '$gramsStr${_selectedFood!.unitType.unitSuffix}';
                    }

                    final cal = _selectedFood!.calculateCalories(effectiveGrams);
                    final prot = _selectedFood!.calculateProtein(effectiveGrams);
                    final carbs = _selectedFood!.calculateCarbs(effectiveGrams);
                    final fat = _selectedFood!.calculateFat(effectiveGrams);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displaySubtitle,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${cal.toStringAsFixed(0)} kcal',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.caloriesColor, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('P: ${prot.toStringAsFixed(1)}g', style: const TextStyle(fontSize: 11, color: AppTheme.proteinColor, fontWeight: FontWeight.bold)),
                              Text('C: ${carbs.toStringAsFixed(1)}g', style: const TextStyle(fontSize: 11, color: AppTheme.carbsColor, fontWeight: FontWeight.bold)),
                              Text('G: ${fat.toStringAsFixed(1)}g', style: const TextStyle(fontSize: 11, color: AppTheme.fatColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit,
                child: const Text('Registrar Refeição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
