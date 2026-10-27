import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';

class FoodFormDialog extends StatefulWidget {
  final FoodItem? initialFood;
  final String? initialName;
  final double? initialCalories;
  final double? initialProtein;
  final double? initialCarbs;
  final double? initialFat;

  const FoodFormDialog({
    super.key,
    this.initialFood,
    this.initialName,
    this.initialCalories,
    this.initialProtein,
    this.initialCarbs,
    this.initialFat,
  });

  @override
  State<FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<FoodFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _calController;
  late final TextEditingController _protController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  late FoodUnitType _unitType;
  late List<FoodPortion> _portions;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFood;
    _nameController = TextEditingController(text: f?.name ?? widget.initialName ?? '');
    _calController = TextEditingController(
      text: f != null 
          ? f.calories.toStringAsFixed(1) 
          : (widget.initialCalories?.toStringAsFixed(1) ?? '0.0'),
    );
    _protController = TextEditingController(
      text: f != null 
          ? f.protein.toStringAsFixed(1) 
          : (widget.initialProtein?.toStringAsFixed(1) ?? '0.0'),
    );
    _carbsController = TextEditingController(
      text: f != null 
          ? f.carbs.toStringAsFixed(1) 
          : (widget.initialCarbs?.toStringAsFixed(1) ?? '0.0'),
    );
    _fatController = TextEditingController(
      text: f != null 
          ? f.fat.toStringAsFixed(1) 
          : (widget.initialFat?.toStringAsFixed(1) ?? '0.0'),
    );
    _unitType = f?.unitType ?? FoodUnitType.per100g;
    _portions = List.from(f?.portions ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calController.dispose();
    _protController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _openAddPortionDialog() async {
    final nameCtrl = TextEditingController();
    final gramsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPortion = await showDialog<FoodPortion>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Porção / Medida'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da Porção *',
                  hintText: 'Ex: Ovo médio, Fatia de pão, 1 colher',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Informe o nome da porção';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: gramsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso / Quantidade (${_unitType.unitSuffix}) *',
                  hintText: 'Ex: 55',
                  suffixText: _unitType.unitSuffix,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  final parsed = double.tryParse((val ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Informe uma quantidade válida';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final grams = double.parse(gramsCtrl.text.replaceAll(',', '.'));
                final portion = FoodPortion(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  grams: grams,
                );
                Navigator.of(ctx).pop(portion);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (newPortion != null) {
      setState(() {
        _portions.add(newPortion);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.initialFood?.id ?? const Uuid().v4();
    final food = FoodItem(
      id: id,
      name: _nameController.text.trim(),
      unitType: _unitType,
      calories: double.tryParse(_calController.text.replaceAll(',', '.')) ?? 0.0,
      protein: double.tryParse(_protController.text.replaceAll(',', '.')) ?? 0.0,
      carbs: double.tryParse(_carbsController.text.replaceAll(',', '.')) ?? 0.0,
      fat: double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0.0,
      isPendingNutrition: false,
      portions: _portions,
    );

    Navigator.of(context).pop(food);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialFood != null && !widget.initialFood!.isPendingNutrition;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Alimento' : 'Novo Alimento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Alimento *',
                  hintText: 'Ex: Arroz Branco Cozido',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Informe o nome do alimento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FoodUnitType>(
                initialValue: _unitType,
                decoration: const InputDecoration(
                  labelText: 'Unidade de Medida / Base *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: FoodUnitType.values.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _unitType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _calController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Calorias (kcal)',
                        helperText: _unitType.helperDescription,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _protController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Proteínas (g)',
                        helperText: _unitType.helperDescription,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Carboidratos (g)',
                        helperText: _unitType.helperDescription,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Gorduras (g)',
                        helperText: _unitType.helperDescription,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Porções / Medidas Personalizadas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
                    onPressed: _openAddPortionDialog,
                  ),
                ],
              ),
              if (_portions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Opcional: cadastre medidas como "Ovo médio (55g)" ou "Fatia (25g)" para registrar com 1 clique.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ..._portions.map((portion) {
                  final cal = double.tryParse(_calController.text.replaceAll(',', '.')) ?? 0.0;
                  final factor = _unitType.isBase100 ? (portion.grams / 100.0) : portion.grams;
                  final portionCal = cal * factor;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${portion.name} (${portion.grams % 1 == 0 ? portion.grams.toInt() : portion.grams}${_unitType.unitSuffix})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              if (cal > 0)
                                Text(
                                  '≈ ${portionCal.toStringAsFixed(0)} kcal por porção',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                          tooltip: 'Remover porção',
                          onPressed: () {
                            setState(() {
                              _portions.remove(portion);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
