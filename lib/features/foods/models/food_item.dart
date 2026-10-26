enum FoodUnitType {
  per100g('Por 100g'),
  per1g('Por 1g');

  final String label;
  const FoodUnitType(this.label);

  static FoodUnitType fromString(String value) {
    if (value == 'per1g') return FoodUnitType.per1g;
    return FoodUnitType.per100g;
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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double calculateCalories(double grams) {
    final factor = unitType == FoodUnitType.per100g ? (grams / 100.0) : grams;
    return calories * factor;
  }

  double calculateProtein(double grams) {
    final factor = unitType == FoodUnitType.per100g ? (grams / 100.0) : grams;
    return protein * factor;
  }

  double calculateCarbs(double grams) {
    final factor = unitType == FoodUnitType.per100g ? (grams / 100.0) : grams;
    return carbs * factor;
  }

  double calculateFat(double grams) {
    final factor = unitType == FoodUnitType.per100g ? (grams / 100.0) : grams;
    return fat * factor;
  }

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
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      unitType: FoodUnitType.fromString(map['unit_type'] as String? ?? 'per100g'),
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      isPendingNutrition: (map['is_pending_nutrition'] as int? ?? 0) == 1,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
