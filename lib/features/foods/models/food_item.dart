import 'dart:convert';
import 'package:my_meal/features/foods/models/food_portion.dart';

enum FoodUnitType {
  per100g('Por 100g', 'g', 'em 100g'),
  per1g('Por 1g', 'g', 'em 1g'),
  per100ml('Por 100ml', 'ml', 'em 100ml'),
  per1ml('Por 1ml', 'ml', 'em 1ml'),
  unit('Por unidade', 'un', 'em 1 unidade'),
  slice('Por fatia', 'fatia', 'em 1 fatia'),
  tablespoon('Por colher de sopa', 'colher', 'em 1 colher'),
  teaspoon('Por colher de chá', 'colher (chá)', 'em 1 colher de chá'),
  scoop('Por dosador (scoop)', 'scoop', 'em 1 scoop'),
  portion('Por porção', 'porção', 'em 1 porção');

  final String label;
  final String unitSuffix;
  final String helperDescription;

  const FoodUnitType(this.label, this.unitSuffix, this.helperDescription);

  bool get isBase100 => this == FoodUnitType.per100g || this == FoodUnitType.per100ml;

  String formatAmount(double amount) {
    final numStr = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1);
    switch (this) {
      case FoodUnitType.per100g:
      case FoodUnitType.per1g:
        return '${numStr}g';
      case FoodUnitType.per100ml:
      case FoodUnitType.per1ml:
        return '${numStr}ml';
      case FoodUnitType.unit:
        return '$numStr un';
      case FoodUnitType.slice:
        return amount == 1 ? '1 fatia' : '$numStr fatias';
      case FoodUnitType.portion:
        return amount == 1 ? '1 porção' : '$numStr porções';
      case FoodUnitType.tablespoon:
        return amount == 1 ? '1 colher' : '$numStr colheres';
      case FoodUnitType.teaspoon:
        return amount == 1 ? '1 colher (chá)' : '$numStr colheres (chá)';
      case FoodUnitType.scoop:
        return amount == 1 ? '1 scoop' : '$numStr scoops';
    }
  }

  static FoodUnitType fromString(String value) {
    final clean = value.trim().toLowerCase();
    switch (clean) {
      case 'per1g':
      case '1g':
        return FoodUnitType.per1g;
      case 'per100ml':
      case '100ml':
        return FoodUnitType.per100ml;
      case 'per1ml':
      case '1ml':
      case 'ml':
        return FoodUnitType.per1ml;
      case 'unit':
      case 'unidade':
      case 'un':
        return FoodUnitType.unit;
      case 'slice':
      case 'fatia':
        return FoodUnitType.slice;
      case 'tablespoon':
      case 'colher':
      case 'colher de sopa':
        return FoodUnitType.tablespoon;
      case 'teaspoon':
      case 'colher de cha':
      case 'colher de chá':
        return FoodUnitType.teaspoon;
      case 'scoop':
      case 'dosador':
        return FoodUnitType.scoop;
      case 'portion':
      case 'porcao':
      case 'porção':
        return FoodUnitType.portion;
      case 'per100g':
      case '100g':
      default:
        return FoodUnitType.per100g;
    }
  }
}

class FoodItem {
  final String id;
  final String name;
  final FoodUnitType unitType;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool isPendingNutrition;
  final List<FoodPortion> portions;
  final DateTime createdAt;

  FoodItem({
    required this.id,
    required this.name,
    this.unitType = FoodUnitType.per100g,
    this.calories = 0.0,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fat = 0.0,
    this.isPendingNutrition = false,
    this.portions = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double calculateCalories(double amount) {
    final factor = unitType.isBase100 ? (amount / 100.0) : amount;
    return calories * factor;
  }

  double calculateProtein(double amount) {
    final factor = unitType.isBase100 ? (amount / 100.0) : amount;
    return protein * factor;
  }

  double calculateCarbs(double amount) {
    final factor = unitType.isBase100 ? (amount / 100.0) : amount;
    return carbs * factor;
  }

  double calculateFat(double amount) {
    final factor = unitType.isBase100 ? (amount / 100.0) : amount;
    return fat * factor;
  }

  double calculatePortionCalories(FoodPortion portion, [double count = 1.0]) =>
      calculateCalories(portion.grams * count);

  double calculatePortionProtein(FoodPortion portion, [double count = 1.0]) =>
      calculateProtein(portion.grams * count);

  double calculatePortionCarbs(FoodPortion portion, [double count = 1.0]) =>
      calculateCarbs(portion.grams * count);

  double calculatePortionFat(FoodPortion portion, [double count = 1.0]) =>
      calculateFat(portion.grams * count);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit_type': unitType.name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'is_pending_nutrition': isPendingNutrition ? 1 : 0,
      'portions': portions.isNotEmpty ? jsonEncode(portions.map((p) => p.toMap()).toList()) : null,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    List<FoodPortion> portions = const [];
    if (map['portions'] != null) {
      try {
        final rawPortions = map['portions'];
        if (rawPortions is String && rawPortions.trim().isNotEmpty) {
          final decoded = jsonDecode(rawPortions);
          if (decoded is List) {
            portions = decoded
                .map((p) => FoodPortion.fromMap(p as Map<String, dynamic>))
                .toList();
          }
        } else if (rawPortions is List) {
          portions = rawPortions
              .map((p) => FoodPortion.fromMap(p as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      unitType: FoodUnitType.fromString(map['unit_type'] as String? ?? 'per100g'),
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      isPendingNutrition: (map['is_pending_nutrition'] as int? ?? 0) == 1,
      portions: portions,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
    );
  }

  FoodItem copyWith({
    String? id,
    String? name,
    FoodUnitType? unitType,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    bool? isPendingNutrition,
    List<FoodPortion>? portions,
    DateTime? createdAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unitType: unitType ?? this.unitType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      isPendingNutrition: isPendingNutrition ?? this.isPendingNutrition,
      portions: portions ?? this.portions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
