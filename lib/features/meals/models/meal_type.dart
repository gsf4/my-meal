import 'package:flutter/material.dart';

enum MealType {
  breakfast('Café da Manhã', Icons.wb_sunny_outlined),
  lunch('Almoço', Icons.restaurant_outlined),
  dinner('Jantar', Icons.nightlife_outlined),
  snack('Lanches', Icons.coffee_outlined);

  final String label;
  final IconData icon;

  const MealType(this.label, this.icon);

  static MealType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'breakfast':
      case 'cafe':
      case 'café':
      case 'cafe_da_manha':
      case 'café da manhã':
        return MealType.breakfast;
      case 'lunch':
      case 'almoco':
      case 'almoço':
        return MealType.lunch;
      case 'dinner':
      case 'janta':
      case 'jantar':
        return MealType.dinner;
      case 'snack':
      case 'lanche':
      case 'lanches':
      default:
        return MealType.snack;
    }
  }

  static MealType fromCurrentTime([DateTime? time]) {
    final now = time ?? DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final totalMinutes = hour * 60 + minute;

    if (totalMinutes >= 5 * 60 && totalMinutes < 11 * 60) {
      return MealType.breakfast;
    } else if (totalMinutes >= 11 * 60 && totalMinutes < 15 * 60 + 30) {
      return MealType.lunch;
    } else if (totalMinutes >= 15 * 60 + 30 && totalMinutes < 19 * 60) {
      return MealType.snack;
    } else {
      return MealType.dinner;
    }
  }
}
