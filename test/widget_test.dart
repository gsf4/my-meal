import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/main.dart';

void main() {
  testWidgets('MyMealApp carrega casca de navegação', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyMealApp(showSplash: false),
      ),
    );

    expect(find.text('My Meal'), findsOneWidget);
    expect(find.text('Diário'), findsOneWidget);
    expect(find.text('Alimentos'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });
}
