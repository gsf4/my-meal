import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_meal/features/splash/presentation/screens/animated_splash_screen.dart';
import 'package:my_meal/features/splash/presentation/widgets/color_stream_painter.dart';

void main() {
  group('AnimatedSplashScreen Tests', () {
    testWidgets('Inicia com fundo branco e CustomPaint de feixes de cor', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimatedSplashScreen(
              animationDuration: const Duration(milliseconds: 1000),
              onAnimationComplete: () {},
            ),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('Avança e exibe o nome do app e subtítulo durante a animação', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimatedSplashScreen(
              animationDuration: const Duration(milliseconds: 1000),
              onAnimationComplete: () {},
            ),
          ),
        ),
      );

      // Avança até 85% da animação (850ms)
      await tester.pump(const Duration(milliseconds: 850));

      expect(find.text('My Meal'), findsOneWidget);
      expect(find.text('Nutrição Inteligente'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Chama onAnimationComplete ao finalizar a duração programada', (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimatedSplashScreen(
              animationDuration: const Duration(milliseconds: 500),
              onAnimationComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 550));
      expect(completed, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('Toque na tela permite pular a animação imediatamente', (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimatedSplashScreen(
              animationDuration: const Duration(milliseconds: 3000),
              onAnimationComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      expect(completed, isFalse);

      // Toca na tela durante os primeiros instantes
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(completed, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('Navega para MainNavigationShell quando onAnimationComplete for nulo', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AnimatedSplashScreen(
              animationDuration: Duration(milliseconds: 200),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Diário'), findsOneWidget);
      expect(find.text('Alimentos'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    });

    test('ColorStreamPainter gera lista de feixes com as cores da maçã', () {
      final streaks = ColorStreamPainter.generateStreaks();
      expect(streaks.length, 48);

      final hasRed = streaks.any((s) => s.color == const Color(0xFFE53935));
      final hasGreen = streaks.any((s) => s.color == const Color(0xFF4CAF50));
      final hasYellow = streaks.any((s) => s.color == const Color(0xFFFFD54F));

      expect(hasRed, isTrue);
      expect(hasGreen, isTrue);
      expect(hasYellow, isTrue);
    });
  });
}
