import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';

class MealPlanOptimizationResult {
  final List<VoiceDetectedFoodItem> items;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String? note;

  const MealPlanOptimizationResult({
    required this.items,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.note,
  });
}

class MealPlanOptimizer {
  /// Otimiza as quantidades dos itens informados para bater a meta de proteína
  /// restante com prioridade máxima e preencher o saldo de calorias com os demais alimentos.
  static MealPlanOptimizationResult optimize({
    required List<VoiceDetectedFoodItem> items,
    required double targetCalories,
    required double targetProtein,
  }) {
    if (items.isEmpty) {
      return const MealPlanOptimizationResult(
        items: [],
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
      );
    }

    // Cria cópia dos itens para manipulação
    final optimizedItems = items.map((it) => it.copyWith()).toList();

    // Calcula a densidade proteica de cada alimento (g de proteína por grama de alimento)
    // e densidade calórica (kcal por grama de alimento)
    final proteinDensities = <VoiceDetectedFoodItem, double>{};
    final calorieDensities = <VoiceDetectedFoodItem, double>{};

    for (final item in optimizedItems) {
      final food = item.matchedFood;
      double protPerGram = 0.0;
      double calPerGram = 0.0;

      if (food != null) {
        if (food.unitType == FoodUnitType.per100g) {
          protPerGram = food.protein / 100.0;
          calPerGram = food.calories / 100.0;
        } else {
          protPerGram = food.protein;
          calPerGram = food.calories;
        }
      } else {
        protPerGram = (item.estimatedProteinPer100g ?? 0.0) / 100.0;
        calPerGram = (item.estimatedCaloriesPer100g ?? 100.0) / 100.0;
      }

      proteinDensities[item] = protPerGram;
      calorieDensities[item] = calPerGram > 0 ? calPerGram : 1.0;
    }

    // Ordena os itens pela densidade proteica decrescente
    final sortedByProtein = List<VoiceDetectedFoodItem>.from(optimizedItems)
      ..sort((a, b) => (proteinDensities[b] ?? 0).compareTo(proteinDensities[a] ?? 0));

    // Identifica alimentos ricos em proteína (>= 5g / 100g ou a melhor fonte disponível)
    final primaryProteinSources = sortedByProtein
        .where((it) => (proteinDensities[it] ?? 0) >= 0.05)
        .toList();

    // Se nenhum item tiver >= 5g/100g, seleciona o item com a maior densidade proteica
    final proteinItems = primaryProteinSources.isNotEmpty
        ? primaryProteinSources
        : [sortedByProtein.first];

    final nonProteinItems = optimizedItems
        .where((it) => !proteinItems.contains(it))
        .toList();

    String? optimizationNote;
    final cleanTargetProtein = targetProtein.clamp(0.0, 500.0);
    final cleanTargetCalories = targetCalories.clamp(0.0, 5000.0);

    // PASSO 1: Bater a meta de proteína (Prioridade Absoluta)
    double caloriesConsumedByProtein = 0.0;

    if (cleanTargetProtein > 0) {
      final proteinPerFoodTarget = cleanTargetProtein / proteinItems.length;

      for (final pItem in proteinItems) {
        final protPerGram = proteinDensities[pItem] ?? 0.0;
        final food = pItem.matchedFood;

        if (protPerGram <= 0) {
          pItem.grams = 100.0;
          continue;
        }

        // Se o alimento possui porções configuradas (ex: Ovo médio = 55g)
        if (pItem.portionId != null && food != null && food.portions.isNotEmpty) {
          final portion = food.portions.firstWhere(
            (p) => p.id == pItem.portionId,
            orElse: () => food.portions.first,
          );

          final protPerPortion = food.calculateProtein(portion.grams);
          if (protPerPortion > 0) {
            // Calcula quantas porções inteiras cobrem a meta de proteína
            double portions = (proteinPerFoodTarget / protPerPortion).ceilToDouble();
            // Verifica se arredondar para o mais próximo faz mais sentido caso passe muito
            if (portions > 1) {
              final under = (portions - 1) * protPerPortion;
              final over = portions * protPerPortion;
              if ((under - proteinPerFoodTarget).abs() < (over - proteinPerFoodTarget).abs()) {
                portions = portions - 1;
              }
            }
            if (portions < 1.0) portions = 1.0;

            pItem.portionQuantity = portions;
            pItem.portionName = portion.name;
            pItem.portionId = portion.id;
            pItem.grams = portions * portion.grams;
          } else {
            final rawGrams = proteinPerFoodTarget / protPerGram;
            pItem.grams = ((rawGrams / 5.0).round() * 5.0).clamp(15.0, 800.0);
          }
        } else {
          // Baseado em gramas diretamente
          final rawGrams = proteinPerFoodTarget / protPerGram;
          // Arredonda para múltiplo de 5g
          pItem.grams = ((rawGrams / 5.0).round() * 5.0).clamp(15.0, 800.0);
        }

        caloriesConsumedByProtein += pItem.displayCalories;
      }
    } else {
      // Proteína já estava batida hoje
      optimizationNote = 'Sua meta de proteína já foi batida hoje! Quantidades calculadas para preencher as calorias.';
      for (final pItem in proteinItems) {
        if (pItem.portionId != null && pItem.matchedFood != null && pItem.matchedFood!.portions.isNotEmpty) {
          final portion = pItem.matchedFood!.portions.firstWhere((p) => p.id == pItem.portionId!);
          pItem.portionQuantity = 1.0;
          pItem.grams = portion.grams;
        } else {
          pItem.grams = 50.0;
        }
        caloriesConsumedByProtein += pItem.displayCalories;
      }
    }

    // PASSO 2: Preencher o restante das calorias com os demais alimentos (Carboidratos, Gorduras, etc.)
    final remainingCaloriesForOthers = cleanTargetCalories - caloriesConsumedByProtein;

    if (nonProteinItems.isNotEmpty) {
      if (remainingCaloriesForOthers > 20) {
        final calPerOther = remainingCaloriesForOthers / nonProteinItems.length;

        for (final other in nonProteinItems) {
          final calDensity = calorieDensities[other] ?? 1.0;
          final food = other.matchedFood;

          if (other.portionId != null && food != null && food.portions.isNotEmpty) {
            final portion = food.portions.firstWhere(
              (p) => p.id == other.portionId,
              orElse: () => food.portions.first,
            );
            final portionCals = food.calculateCalories(portion.grams);
            if (portionCals > 0) {
              final portions = (calPerOther / portionCals).roundToDouble().clamp(1.0, 20.0);
              other.portionQuantity = portions;
              other.portionName = portion.name;
              other.portionId = portion.id;
              other.grams = portions * portion.grams;
            } else {
              other.grams = 50.0;
            }
          } else {
            // Em gramas (ex: goma de tapioca, arroz, aveia)
            final rawGrams = calPerOther / calDensity;
            // Arredonda para múltiplo de 5g
            other.grams = ((rawGrams / 5.0).round() * 5.0).clamp(10.0, 600.0);
          }
        }
      } else {
        // As calorias do alimento proteico já cobriram ou ultrapassaram o saldo calórico
        optimizationNote = 'A meta de proteína preencheu grande parte das calorias restantes. Sugeridas porções mínimas para os outros alimentos.';
        for (final other in nonProteinItems) {
          if (other.portionId != null && other.matchedFood != null && other.matchedFood!.portions.isNotEmpty) {
            final portion = other.matchedFood!.portions.firstWhere((p) => p.id == other.portionId!);
            other.portionQuantity = 1.0;
            other.grams = portion.grams;
          } else {
            other.grams = 30.0; // Porção mínima sensata
          }
        }
      }
    } else {
      // O usuário falou apenas o alimento proteico (ex: só falou ovos)
      // Se não havia meta de proteína (proteína já batida hoje), usa o alimento para preencher as calorias
      if (cleanTargetProtein <= 0 && cleanTargetCalories > 0) {
        final pItem = proteinItems.first;
        final calDensity = calorieDensities[pItem] ?? 1.0;
        if (pItem.portionId != null && pItem.matchedFood != null && pItem.matchedFood!.portions.isNotEmpty) {
          final portion = pItem.matchedFood!.portions.firstWhere((p) => p.id == pItem.portionId!);
          final portionCals = pItem.matchedFood!.calculateCalories(portion.grams);
          if (portionCals > 0) {
            final portions = (cleanTargetCalories / portionCals).roundToDouble().clamp(1.0, 15.0);
            pItem.portionQuantity = portions;
            pItem.grams = portions * portion.grams;
          }
        } else {
          final rawGrams = cleanTargetCalories / calDensity;
          pItem.grams = ((rawGrams / 5.0).round() * 5.0).clamp(15.0, 800.0);
        }
      }
    }

    // Calcula os totais finais resultantes
    double totalCal = 0.0;
    double totalProt = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final it in optimizedItems) {
      totalCal += it.displayCalories;
      totalProt += it.displayProtein;
      totalCarbs += it.displayCarbs;
      totalFat += it.displayFat;
    }

    return MealPlanOptimizationResult(
      items: optimizedItems,
      totalCalories: totalCal,
      totalProtein: totalProt,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      note: optimizationNote,
    );
  }
}
