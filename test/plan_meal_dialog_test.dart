import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/dashboard/presentation/widgets/meal_section_card.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/models/food_portion.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';
import 'package:my_meal/features/voice_logging/presentation/widgets/voice_review_bottom_sheet.dart';

void main() {
  group('PlanMealDialog & Planning Flow Tests', () {
    testWidgets('MealSectionCard exibe botão de planejar e atalho em refeição vazia', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MealSectionCard(
                mealType: MealType.dinner,
                logs: const [],
                selectedDate: DateTime(2026, 10, 26),
              ),
            ),
          ),
        ),
      );

      // Ícone auto_awesome no cabeçalho
      expect(find.byIcon(Icons.auto_awesome), findsNWidgets(2)); // Um no header, outro no atalho vazio
      expect(find.textContaining('Planejar jantar com IA por voz'), findsOneWidget);
    });

    testWidgets('Tocar no botão de planejar abre o PlanMealDialog com metas restantes', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MealSectionCard(
                mealType: MealType.dinner,
                logs: const [],
                selectedDate: DateTime(2026, 10, 26),
              ),
            ),
          ),
        ),
      );

      // Toca no botão de planejar
      await tester.tap(find.byTooltip('Planejar com IA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verifica elementos do diálogo
      expect(find.text('Planejar Jantar'), findsOneWidget);
      expect(find.text('Metas restantes do dia:'), findsOneWidget);
      expect(find.textContaining('Prioridade: Proteína'), findsOneWidget);
      expect(find.text('Proteína Restante'), findsOneWidget);
      expect(find.text('Calorias Restantes'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Toque no microfone para falar'), findsOneWidget);
    });

    testWidgets('VoiceReviewBottomSheet em modo de planejamento exibe banner e botão personalizado', (WidgetTester tester) async {
      final eggFood = FoodItem(
        id: 'egg_1',
        name: 'Ovo Cozido Inteiro',
        unitType: FoodUnitType.per100g,
        calories: 146.0,
        protein: 13.3,
        carbs: 0.6,
        fat: 9.5,
        portions: [
          const FoodPortion(id: 'med', name: 'Ovo médio', grams: 55.0),
        ],
      );

      final result = VoiceMealResult(
        suggestedMealType: MealType.dinner,
        items: [
          VoiceDetectedFoodItem(
            spokenName: 'ovos médios',
            matchedFood: eggFood,
            grams: 220.0,
            portionId: 'med',
            portionName: 'Ovo médio',
            portionQuantity: 4.0,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceReviewBottomSheet(
                initialResult: result,
                targetDate: DateTime(2026, 10, 26),
                isPlanningMode: true,
                targetRemainingCalories: 450.0,
                targetRemainingProtein: 28.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Planejamento de Refeição'), findsOneWidget);
      expect(find.text('Metas Restantes a Bater'), findsOneWidget);
      expect(find.textContaining('4× Ovo médio (220g)'), findsOneWidget);
      expect(find.text('Confirmar Refeição Planejada'), findsOneWidget);
    });
  });
}
