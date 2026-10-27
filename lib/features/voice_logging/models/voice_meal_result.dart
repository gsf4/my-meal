import 'package:uuid/uuid.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';

class VoiceDetectedFoodItem {
  final String id;
  final String spokenName;
  FoodItem? matchedFood;
  double grams;
  double? estimatedCaloriesPer100g;
  double? estimatedProteinPer100g;
  double? estimatedCarbsPer100g;
  double? estimatedFatPer100g;

  String? portionId;
  String? portionName;
  double? portionQuantity;

  VoiceDetectedFoodItem({
    String? id,
    required this.spokenName,
    this.matchedFood,
    required this.grams,
    this.portionId,
    this.portionName,
    this.portionQuantity,
    this.estimatedCaloriesPer100g,
    this.estimatedProteinPer100g,
    this.estimatedCarbsPer100g,
    this.estimatedFatPer100g,
  }) : id = id ?? const Uuid().v4();

  bool get hasMatch => matchedFood != null && !matchedFood!.isPendingNutrition;
  bool get isUnknown => matchedFood == null;

  String get displayAmount {
    if (portionName != null && portionQuantity != null && portionQuantity! > 0) {
      final formattedQty = portionQuantity! % 1 == 0 
          ? portionQuantity!.toInt().toString() 
          : portionQuantity!.toStringAsFixed(1);
      final formattedGrams = grams % 1 == 0 ? grams.toInt().toString() : grams.toStringAsFixed(1);
      final suffix = matchedFood?.unitType.unitSuffix ?? 'g';
      return '$formattedQty\u00D7 $portionName ($formattedGrams$suffix)';
    }
    return matchedFood?.unitType.formatAmount(grams) ?? '${grams.toStringAsFixed(0)}g';
  }

  // Calorias calculadas ou estimadas
  double get displayCalories {
    if (matchedFood != null) {
      return matchedFood!.calculateCalories(grams);
    }
    if (estimatedCaloriesPer100g != null) {
      return (estimatedCaloriesPer100g! * (grams / 100.0));
    }
    return 0.0;
  }

  double get displayProtein {
    if (matchedFood != null) {
      return matchedFood!.calculateProtein(grams);
    }
    if (estimatedProteinPer100g != null) {
      return (estimatedProteinPer100g! * (grams / 100.0));
    }
    return 0.0;
  }

  double get displayCarbs {
    if (matchedFood != null) {
      return matchedFood!.calculateCarbs(grams);
    }
    if (estimatedCarbsPer100g != null) {
      return (estimatedCarbsPer100g! * (grams / 100.0));
    }
    return 0.0;
  }

  double get displayFat {
    if (matchedFood != null) {
      return matchedFood!.calculateFat(grams);
    }
    if (estimatedFatPer100g != null) {
      return (estimatedFatPer100g! * (grams / 100.0));
    }
    return 0.0;
  }

  VoiceDetectedFoodItem copyWith({
    String? id,
    String? spokenName,
    FoodItem? matchedFood,
    double? grams,
    String? portionId,
    String? portionName,
    double? portionQuantity,
    double? estimatedCaloriesPer100g,
    double? estimatedProteinPer100g,
    double? estimatedCarbsPer100g,
    double? estimatedFatPer100g,
  }) {
    return VoiceDetectedFoodItem(
      id: id ?? this.id,
      spokenName: spokenName ?? this.spokenName,
      matchedFood: matchedFood ?? this.matchedFood,
      grams: grams ?? this.grams,
      portionId: portionId ?? this.portionId,
      portionName: portionName ?? this.portionName,
      portionQuantity: portionQuantity ?? this.portionQuantity,
      estimatedCaloriesPer100g: estimatedCaloriesPer100g ?? this.estimatedCaloriesPer100g,
      estimatedProteinPer100g: estimatedProteinPer100g ?? this.estimatedProteinPer100g,
      estimatedCarbsPer100g: estimatedCarbsPer100g ?? this.estimatedCarbsPer100g,
      estimatedFatPer100g: estimatedFatPer100g ?? this.estimatedFatPer100g,
    );
  }
}

class VoiceMealResult {
  final MealType suggestedMealType;
  final List<VoiceDetectedFoodItem> items;
  final String? rawTranscript;

  const VoiceMealResult({
    required this.suggestedMealType,
    required this.items,
    this.rawTranscript,
  });
}
