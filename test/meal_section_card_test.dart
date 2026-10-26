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
  bool updateAmountCalled = false;
  String? updatedId;
  double? updatedAmount;
  double? updatedPortionQuantity;

  TestMealNotifier() : super(FakeMealRepo(), DateTime(2026, 10, 26)) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> deleteMealLog(String id) async {
    deleteCalled = true;
    deletedId = id;
  }

  @override
  Future<void> updateConsumedAmount(String id, double newAmount, {double? newPortionQuantity}) async {
    updateAmountCalled = true;
    updatedId = id;
    updatedAmount = newAmount;
    updatedPortionQuantity = newPortionQuantity;
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

  testWidgets('Ao clicar no alimento registrado, exibe diálogo de edição de quantidade e salva a alteração', (WidgetTester tester) async {
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

    // Clica no item de alimento
    await tester.tap(find.text('Pão de Forma'));
    await tester.pumpAndSettle();

    // Diálogo de edição deve abrir
    expect(find.text('Editar Quantidade'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Altera a quantidade para 75
    await tester.enterText(find.byType(TextField), '75');
    await tester.pumpAndSettle();

    // Clica em Salvar
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Diálogo fechou e notifier foi chamado com os valores corretos
    expect(find.text('Editar Quantidade'), findsNothing);
    expect(notifier.updateAmountCalled, isTrue);
    expect(notifier.updatedId, 'log-1');
    expect(notifier.updatedAmount, 75.0);
  });

  testWidgets('Header não possui o ícone de copiar e expande para exibir os macronutrientes ao clicar quando houver alimentos', (WidgetTester tester) async {
    final food = FoodItem(
      id: 'f-1',
      name: 'Ovo Cozido',
      calories: 143,
      protein: 13.0,
      carbs: 1.0,
      fat: 9.5,
    );

    final log = MealLog(
      id: 'log-1',
      date: DateTime(2026, 10, 26),
      mealType: MealType.breakfast,
      foodId: food.id,
      consumedAmount: 100,
      food: food,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealLogsProvider.overrideWith((ref) => TestMealNotifier()),
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

    // O ícone de copiar foi removido do header
    expect(find.byIcon(Icons.copy_all_outlined), findsNothing);

    // Inicialmente, os macronutrientes da refeição estão recolhidos
    expect(find.text('Proteínas'), findsNothing);
    expect(find.text('Carboidratos'), findsNothing);
    expect(find.text('Gorduras'), findsNothing);

    // O chevron para expandir deve estar visível
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    // Clica no header da refeição
    await tester.tap(find.text('Café da Manhã'));
    await tester.pumpAndSettle();

    // Agora os macronutrientes da refeição devem estar visíveis!
    expect(find.text('Proteínas'), findsOneWidget);
    expect(find.text('13.0g'), findsOneWidget);
    expect(find.text('Carboidratos'), findsOneWidget);
    expect(find.text('1.0g'), findsOneWidget);
    expect(find.text('Gorduras'), findsOneWidget);
    expect(find.text('9.5g'), findsOneWidget);

    // Chevron mudou para cima
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    // Clica novamente no header para recolher
    await tester.tap(find.text('Café da Manhã'));
    await tester.pumpAndSettle();

    expect(find.text('Proteínas'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('Exibe e edita alimento cadastrado por unidade (ex: 2 ovos médios -> 2 un)', (WidgetTester tester) async {
    final egg = FoodItem(
      id: 'egg-1',
      name: 'Ovo Médio',
      unitType: FoodUnitType.unit,
      calories: 70,
      protein: 6.0,
      carbs: 0.5,
      fat: 5.0,
    );

    final log = MealLog(
      id: 'log-egg',
      date: DateTime(2026, 10, 26),
      mealType: MealType.breakfast,
      foodId: egg.id,
      consumedAmount: 2,
      food: egg,
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

    // Deve exibir "2 un" e 140 kcal (2 * 70)
    expect(find.text('Ovo Médio'), findsOneWidget);
    expect(find.text('2 un'), findsOneWidget);
    expect(find.text('140 kcal'), findsWidgets);

    // Toca para editar
    await tester.tap(find.text('Ovo Médio'));
    await tester.pumpAndSettle();

    // Diálogo com suffix un
    expect(find.text('Editar Quantidade'), findsOneWidget);
    expect(find.text('un'), findsOneWidget);

    // Altera para 3 ovos
    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    // Clica em Salvar
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(notifier.updateAmountCalled, isTrue);
    expect(notifier.updatedId, 'log-egg');
    expect(notifier.updatedAmount, 3.0);
  });

  testWidgets('Exibe porção personalizada (ex: 2x Ovo médio (110g)) e permite editar a quantidade de porções', (WidgetTester tester) async {
    final eggFood = FoodItem(
      id: 'egg-taco',
      name: 'Ovo Cozido Inteiro',
      unitType: FoodUnitType.per100g,
      calories: 146.0,
      protein: 13.3,
      carbs: 0.6,
      fat: 9.5,
    );

    // 2 ovos médios de 55g = 110g
    final portionLog = MealLog(
      id: 'log-portion-egg',
      date: DateTime(2026, 10, 26),
      mealType: MealType.breakfast,
      foodId: eggFood.id,
      consumedAmount: 110.0,
      portionId: 'portion-med',
      portionName: 'Ovo médio',
      portionQuantity: 2.0,
      food: eggFood,
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
              logs: [portionLog],
              selectedDate: DateTime(2026, 10, 26),
            ),
          ),
        ),
      ),
    );

    // Deve exibir nome do alimento e formato de porção
    expect(find.text('Ovo Cozido Inteiro'), findsOneWidget);
    expect(find.text('2x Ovo médio (110g)'), findsOneWidget);

    // Toca para editar
    await tester.tap(find.text('Ovo Cozido Inteiro'));
    await tester.pumpAndSettle();

    // Diálogo deve abrir mostrando a porção
    expect(find.text('Editar Quantidade'), findsOneWidget);
    expect(find.text('Medida: Ovo médio (55g)'), findsOneWidget);
    expect(find.text('Quantidade de "Ovo médio"'), findsOneWidget);

    // Altera de 2 para 3 porções (3 * 55g = 165g)
    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    // Subtítulo atualizado no card de pré-visualização
    expect(find.text('3× Ovo médio (165g)'), findsOneWidget);

    // Clica em Salvar
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(notifier.updateAmountCalled, isTrue);
    expect(notifier.updatedId, 'log-portion-egg');
    expect(notifier.updatedAmount, 165.0); // 3 * 55g
    expect(notifier.updatedPortionQuantity, 3.0);
  });
}
