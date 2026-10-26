import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
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
  final _amountController = TextEditingController(text: '100');
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
    _searchController.dispose();
    super.dispose();
  }

  void _createNewFood() async {
    final newFood = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => FoodFormDialog(initialName: _searchController.text),
    );

    if (newFood != null) {
      await ref.read(foodListProvider.notifier).addFood(newFood);
      setState(() {
        _selectedFood = newFood;
      });
    }
  }

  void _submit() {
    if (_selectedFood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um alimento da lista')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 100.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida em gramas')),
      );
      return;
    }

    Navigator.of(context).pop({
      'food': _selectedFood,
      'mealType': _mealType,
      'amount': amount,
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
                            subtitle: Text('${food.calories.toStringAsFixed(0)} kcal / 100g'),
                            trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                            onTap: () {
                              setState(() {
                                _selectedFood = food;
                              });
                            },
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
              // Quantidade consumida em gramas
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantidade consumida (gramas)',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
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
