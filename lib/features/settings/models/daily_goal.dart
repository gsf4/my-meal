import 'package:my_meal/core/constants/app_constants.dart';

class DailyGoal {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const DailyGoal({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory DailyGoal.defaultGoal() {
    return const DailyGoal(
      calories: AppConstants.defaultCalories,
      protein: AppConstants.defaultProtein,
      carbs: AppConstants.defaultCarbs,
      fat: AppConstants.defaultFat,
    );
  }

  DailyGoal copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return DailyGoal(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }
}
