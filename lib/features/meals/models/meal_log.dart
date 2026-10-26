import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';

class MealLog {
  final String id;
  final DateTime date;
  final MealType mealType;
  final String foodId;
  final double consumedAmount; // em gramas
  final DateTime createdAt;
  final FoodItem? food; // Alimento associado (carregado via JOIN)

  MealLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.consumedAmount,
    DateTime? createdAt,
    this.food,
  }) : createdAt = createdAt ?? DateTime.now();

  double get calories => food?.calculateCalories(consumedAmount) ?? 0.0;
  double get protein => food?.calculateProtein(consumedAmount) ?? 0.0;
  double get carbs => food?.calculateCarbs(consumedAmount) ?? 0.0;
  double get fat => food?.calculateFat(consumedAmount) ?? 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'meal_type': mealType.name,
      'food_id': foodId,
      'consumed_amount': consumedAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MealLog.fromMap(Map<String, dynamic> map, {FoodItem? food}) {
    return MealLog(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      mealType: MealType.fromString(map['meal_type'] as String),
      foodId: map['food_id'] as String,
      consumedAmount: (map['consumed_amount'] as num).toDouble(),
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
    DateTime? createdAt,
    FoodItem? food,
  }) {
    return MealLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      createdAt: createdAt ?? this.createdAt,
      food: food ?? this.food,
    );
  }
}
