import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/dashboard/presentation/widgets/meal_section_card.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/meals/repositories/meal_repository.dart';

class TestMealNotifier extends MealLogsNotifier {
  bool deleteCalled = false;
  String? deletedId;

  TestMealNotifier() : super(FakeMealRepo(), DateTime(2026, 10, 26)) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> deleteMealLog(String id) async {
    deleteCalled = true;
    deletedId = id;
  }
}

class FakeMealRepo extends Fake implements MealRepository {}

void main() {
  testWidgets('Ao clicar no botão de fechar, exibe diálogo de confirmação antes de remover', (WidgetTester tester) async {
    final food = FoodItem(
      id: 'f-1',
      name: 'Pão de Forma',
      calories: 140,
      protein: 4.5,
      carbs: 26,
      fat: 1.5,
    );

    final log = MealLog(
      id: 'log-1',
      date: DateTime(2026, 10, 26),
      mealType: MealType.breakfast,
      foodId: food.id,
      consumedAmount: 50,
      food: food,
    );

    final notifier = TestMealNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealLogsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealSectionCard(
              mealType: MealType.breakfast,
              logs: [log],
              selectedDate: DateTime(2026, 10, 26),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pão de Forma'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Clica no botão de remover
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Diálogo de confirmação deve aparecer
    expect(find.text('Remover Alimento'), findsOneWidget);
    expect(find.text('Deseja remover "Pão de Forma" (50g) de Café da Manhã?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    // Clica em Cancelar
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Diálogo fechou e delete NÃO foi chamado
    expect(find.text('Remover Alimento'), findsNothing);
    expect(notifier.deleteCalled, isFalse);

    // Clica no botão de remover novamente
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Desta vez clica em Remover
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    // Diálogo fechou e delete foi chamado com o ID correto
    expect(find.text('Remover Alimento'), findsNothing);
    expect(notifier.deleteCalled, isTrue);
    expect(notifier.deletedId, 'log-1');
  });
}
