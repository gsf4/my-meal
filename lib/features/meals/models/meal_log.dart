import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';

class MealLog {
  final String id;
  final DateTime date;
  final MealType mealType;
  final String foodId;
  final double consumedAmount; // em gramas ou unidade base
  final String? portionId;
  final String? portionName;
  final double? portionQuantity;
  final DateTime createdAt;
  final FoodItem? food; // Alimento associado (carregado via JOIN)

  MealLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.consumedAmount,
    this.portionId,
    this.portionName,
    this.portionQuantity,
    DateTime? createdAt,
    this.food,
  }) : createdAt = createdAt ?? DateTime.now();

  double get calories => food?.calculateCalories(consumedAmount) ?? 0.0;
  double get protein => food?.calculateProtein(consumedAmount) ?? 0.0;
  double get carbs => food?.calculateCarbs(consumedAmount) ?? 0.0;
  double get fat => food?.calculateFat(consumedAmount) ?? 0.0;

  String get displayAmount {
    if (portionName != null && portionQuantity != null && portionQuantity! > 0) {
      final qtyStr = portionQuantity! % 1 == 0 
          ? portionQuantity!.toInt().toString() 
          : portionQuantity!.toStringAsFixed(1);
      final weightStr = consumedAmount % 1 == 0
          ? consumedAmount.toInt().toString()
          : consumedAmount.toStringAsFixed(1);
      final unit = food?.unitType.unitSuffix ?? 'g';
      return '${qtyStr}x $portionName ($weightStr$unit)';
    }
    return food?.unitType.formatAmount(consumedAmount) ?? 
        '${consumedAmount % 1 == 0 ? consumedAmount.toInt() : consumedAmount.toStringAsFixed(1)}g';
  }

  Map<String, dynamic> toMap() {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'date': dateStr,
      'meal_type': mealType.name,
      'food_id': foodId,
      'consumed_amount': consumedAmount,
      'portion_id': portionId,
      'portion_name': portionName,
      'portion_quantity': portionQuantity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MealLog.fromMap(Map<String, dynamic> map, {FoodItem? food}) {
    DateTime parsedDate;
    final rawDate = map['date'] as String;
    try {
      parsedDate = DateTime.parse(rawDate);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return MealLog(
      id: map['id'] as String,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      mealType: MealType.fromString(map['meal_type'] as String),
      foodId: map['food_id'] as String,
      consumedAmount: (map['consumed_amount'] as num).toDouble(),
      portionId: map['portion_id'] as String?,
      portionName: map['portion_name'] as String?,
      portionQuantity: (map['portion_quantity'] as num?)?.toDouble(),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      food: food,
    );
  }

  MealLog copyWith({
    String? id,
    DateTime? date,
    MealType? mealType,
    String? foodId,
    double? consumedAmount,
    String? portionId,
    String? portionName,
    double? portionQuantity,
    DateTime? createdAt,
    FoodItem? food,
  }) {
    return MealLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      portionId: portionId ?? this.portionId,
      portionName: portionName ?? this.portionName,
      portionQuantity: portionQuantity ?? this.portionQuantity,
      createdAt: createdAt ?? this.createdAt,
      food: food ?? this.food,
    );
  }
}
