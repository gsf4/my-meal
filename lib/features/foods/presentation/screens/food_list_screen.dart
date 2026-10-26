import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/presentation/screens/food_form_dialog.dart';
import 'package:my_meal/features/foods/providers/food_providers.dart';

class FoodListScreen extends ConsumerStatefulWidget {
  const FoodListScreen({super.key});

  @override
  ConsumerState<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends ConsumerState<FoodListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFoodForm([FoodItem? food]) async {
    final result = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => FoodFormDialog(initialFood: food),
    );

    if (result != null) {
      if (food != null) {
        ref.read(foodListProvider.notifier).updateFood(result);
      } else {
        ref.read(foodListProvider.notifier).addFood(result);
      }
    }
  }

  void _confirmDelete(FoodItem food) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Alimento'),
        content: Text('Tem certeza que deseja excluir "${food.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(foodListProvider.notifier).deleteFood(food.id);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de Alimentos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar alimentos...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(foodListProvider.notifier).loadFoods('');
                    },
                  ),
              ],
              onChanged: (val) {
                ref.read(foodListProvider.notifier).loadFoods(val);
              },
            ),
          ),
        ),
      ),
      body: foodsAsync.when(
        data: (foods) {
          if (foods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Nenhum alimento cadastrado ainda.'
                        : 'Nenhum alimento encontrado para "${_searchController.text}".',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: foods.length,
            itemBuilder: (context, index) {
              final food = foods[index];
              final isPending = food.isPendingNutrition;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openFoodForm(food),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                food.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isPending)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.warningColor),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warningColor),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pendente de Macros',
                                      style: TextStyle(
                                        color: AppTheme.warningColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () => _confirmDelete(food),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isPending)
                          const Text(
                            'Item registrado por voz. Toque aqui para inserir calorias e macros.',
                            style: TextStyle(color: Colors.orange, fontSize: 13),
                          )
                        else
                          Row(
                            children: [
                              Text(
                                '${food.calories.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.caloriesColor,
                                ),
                              ),
                              Text(
                                ' (${food.unitType.label})',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                              const Spacer(),
                              _buildMacroChip('P: ${food.protein.toStringAsFixed(1)}g', AppTheme.proteinColor),
                              const SizedBox(width: 6),
                              _buildMacroChip('C: ${food.carbs.toStringAsFixed(1)}g', AppTheme.carbsColor),
                              const SizedBox(width: 6),
                              _buildMacroChip('G: ${food.fat.toStringAsFixed(1)}g', AppTheme.fatColor),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar alimentos: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFoodForm(),
        icon: const Icon(Icons.add),
        label: const Text('Novo Alimento'),
      ),
    );
  }

  Widget _buildMacroChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
