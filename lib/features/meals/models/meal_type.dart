import 'package:flutter/material.dart';

enum MealType {
  breakfast('Café da Manhã', 'Café da Manhã', Icons.wb_sunny_outlined),
  lunch('Almoço', 'Almoço', Icons.restaurant_outlined),
  snack('Lanche', 'Lanche (Tarde)', Icons.coffee_outlined),
  dinner('Jantar', 'Jantar', Icons.nightlife_outlined),
  nightSnack('Lanche', 'Lanche (Noite)', Icons.bedtime_outlined);

  final String label;
  final String detailedLabel;
  final IconData icon;

  const MealType(this.label, this.detailedLabel, this.icon);

  static MealType fromString(String value) {
    switch (value.toLowerCase().trim()) {
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
      case 'snack':
      case 'lanche':
      case 'lanches':
      case 'lanche_tarde':
      case 'lanche da tarde':
      case 'lanche 1':
        return MealType.snack;
      case 'dinner':
      case 'janta':
      case 'jantar':
        return MealType.dinner;
      case 'nightsnack':
      case 'night_snack':
      case 'ceia':
      case 'lanche_noite':
      case 'lanche da noite':
      case 'lanche 2':
        return MealType.nightSnack;
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
    } else if (totalMinutes >= 19 * 60 && totalMinutes < 22 * 60) {
      return MealType.dinner;
    } else {
      return MealType.nightSnack;
    }
  }
}
