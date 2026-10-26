import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:my_meal/features/foods/models/food_item.dart';

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
