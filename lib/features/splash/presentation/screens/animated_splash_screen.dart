import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_meal/features/splash/presentation/widgets/color_stream_painter.dart';
import 'package:my_meal/main.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Duration animationDuration;
  final VoidCallback? onAnimationComplete;

  const AnimatedSplashScreen({
    super.key,
    this.animationDuration = const Duration(milliseconds: 2400),
    this.onAnimationComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<ColorStreamStreak> _streaks;
  bool _navigated = false;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    _streaks = ColorStreamPainter.generateStreaks();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Revelação da Maçã com elastic pop (Curves.easeOutBack) entre 62% e 84% do ciclo
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 62),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
    ]).animate(_controller);

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.80, curve: Curves.easeIn),
    );

    // Texto "My Meal" surge logo em seguida entre 75% e 90%
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 0.90, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    // Transição de saída suave
    _exitFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.94, 1.0, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Configura a barra de status do sistema para tema claro (ícones escuros sobre fundo branco)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome, // Toque para pular animação se o usuário preferir
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitFade),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Feixes de cor das bordas e vórtice central
                  CustomPaint(
                    painter: ColorStreamPainter(
                      progress: _controller.value,
                      streaks: _streaks,
                    ),
                  ),

                  // 2. Maçã e Identidade Visual no centro
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Desenho da Maçã com Scale e Opacidade
                        FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                                    blurRadius: 32,
                                    spreadRadius: 6,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/icon/apple_logo_transparent.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Tipografia "My Meal"
                        FadeTransition(
                          opacity: _textOpacity,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'My Meal',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nutrição Inteligente',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Botão discreto de pular no canto superior direito
                  if (_controller.value > 0.25)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 16,
                      child: FadeTransition(
                        opacity: _controller,
                        child: TextButton(
                          onPressed: _navigateToHome,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Pular', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
