import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColorStreamStreak {
  final double startAngle;
  final double startRadiusFactor;
  final Offset targetCenterOffset;
  final Color color;
  final double strokeWidth;
  final double speed;
  final double waveFrequency;
  final double waveAmplitude;
  final double swirlDirection; // 1.0 or -1.0

  const ColorStreamStreak({
    required this.startAngle,
    required this.startRadiusFactor,
    required this.targetCenterOffset,
    required this.color,
    required this.strokeWidth,
    required this.speed,
    required this.waveFrequency,
    required this.waveAmplitude,
    required this.swirlDirection,
  });
}

class ColorStreamPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final List<ColorStreamStreak> streaks;

  ColorStreamPainter({
    required this.progress,
    required this.streaks,
  });

  static List<ColorStreamStreak> generateStreaks() {
    final random = math.Random(42); // Seed fixa para consistência visual estética

    // Paleta exata das cores da maçã (vermelho, laranja, amarelo, verde limão, verde folha)
    const palette = [
      Color(0xFFE53935), // Vermelho Coral
      Color(0xFFD32F2F), // Vermelho Carmim
      Color(0xFFFF5722), // Laranja Avermelhado
      Color(0xFFFF7043), // Laranja Quente
      Color(0xFFFFA726), // Âmbar
      Color(0xFFFFB300), // Tangerina
      Color(0xFFFFD54F), // Amarelo Dourado
      Color(0xFFFFEE58), // Amarelo Brilhante
      Color(0xFF9CCC65), // Verde Limão
      Color(0xFF8BC34A), // Verde Chartreuse
      Color(0xFF4CAF50), // Verde Folha
      Color(0xFF43A047), // Verde Esmeralda
    ];

    final List<ColorStreamStreak> list = [];
    const count = 48;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (random.nextDouble() * 0.2 - 0.1);
      final radiusFactor = 1.15 + random.nextDouble() * 0.45; // além das bordas
      final color = palette[i % palette.length];

      // Destino correspondente aos lobos da maçã:
      // Esquerda: Vermelho/Laranja | Direita: Verde Limão | Centro/Base: Amarelo | Topo: Folha
      Offset target;
      if (color == const Color(0xFFE53935) ||
          color == const Color(0xFFD32F2F) ||
          color == const Color(0xFFFF5722)) {
        target = Offset(-30 + random.nextDouble() * 15, -5 + random.nextDouble() * 30);
      } else if (color == const Color(0xFF4CAF50) ||
                 color == const Color(0xFF43A047)) {
        target = Offset(5 + random.nextDouble() * 15, -45 + random.nextDouble() * 15); // folha no topo
      } else if (color == const Color(0xFF9CCC65) ||
                 color == const Color(0xFF8BC34A)) {
        target = Offset(25 + random.nextDouble() * 15, -10 + random.nextDouble() * 30); // lobo direito verde
      } else {
        target = Offset(-5 + random.nextDouble() * 20, 15 + random.nextDouble() * 25); // centro/base amarelo
      }

      list.add(
        ColorStreamStreak(
          startAngle: angle,
          startRadiusFactor: radiusFactor,
          targetCenterOffset: target,
          color: color,
          strokeWidth: 3.5 + random.nextDouble() * 5.5,
          speed: 0.85 + random.nextDouble() * 0.35,
          waveFrequency: 2.0 + random.nextDouble() * 3.0,
          waveAmplitude: 20.0 + random.nextDouble() * 30.0,
          swirlDirection: random.nextBool() ? 1.0 : -1.0,
        ),
      );
    }

    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(center.dx * center.dx + center.dy * center.dy);

    // 1. Fase de Influxo & Vórtice dos Feixes de Cor
    final streakFade = (1.0 - ((progress - 0.70) / 0.25)).clamp(0.0, 1.0);

    if (streakFade > 0) {
      for (final streak in streaks) {
        final adjustedProgress = (progress * streak.speed).clamp(0.0, 1.0);

        // O head lidera a corrida das bordas ao centro
        final headT = Curves.easeInCubic.transform(
          (adjustedProgress / 0.60).clamp(0.0, 1.0),
        );
        // O tail acompanha com atraso, criando a fita corrida
        final tailT = Curves.easeInQuad.transform(
          ((adjustedProgress - 0.18) / 0.50).clamp(0.0, 1.0),
        );

        if (headT <= 0) continue;

        final path = Path();
        const steps = 18;
        bool started = false;

        for (int step = 0; step <= steps; step++) {
          final stepT = tailT + (headT - tailT) * (step / steps);
          if (stepT < 0 || stepT > 1.0) continue;

          final pt = _calculatePoint(center, maxRadius, streak, stepT);
          if (!started) {
            path.moveTo(pt.dx, pt.dy);
            started = true;
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }

        if (started) {
          final currentAlpha = ((0.90 * streakFade) * (headT > 0.1 ? 1.0 : headT * 10)).clamp(0.0, 1.0);

          // Camada de brilho exterior (Glow)
          final glowPaint = Paint()
            ..color = streak.color.withValues(alpha: currentAlpha * 0.35)
            ..strokeWidth = streak.strokeWidth * 2.2
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawPath(path, glowPaint);

          // Feixe principal nítido
          final mainPaint = Paint()
            ..color = streak.color.withValues(alpha: currentAlpha * 0.85)
            ..strokeWidth = streak.strokeWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, mainPaint);
        }
      }
    }

    // 2. Fase de Aglomeração Central (Vórtice & Massa Multicolorida no Centro)
    // Ativa entre progress 0.40 e 0.85
    if (progress > 0.35 && progress < 0.90) {
      final vortexProgress = ((progress - 0.35) / 0.45).clamp(0.0, 1.0);
      final vortexOpacity = (vortexProgress < 0.6
          ? (vortexProgress / 0.6)
          : (1.0 - (vortexProgress - 0.6) / 0.4)).clamp(0.0, 1.0);

      final swirlAngle = vortexProgress * 3.5 * math.pi;
      final maxVortexRadius = 75.0 * Curves.easeOutQuad.transform(vortexProgress);

      final vortexGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFEE58).withValues(alpha: vortexOpacity * 0.5), // Centro Amarelo
            const Color(0xFFFF5722).withValues(alpha: vortexOpacity * 0.4), // Laranja
            const Color(0xFF9CCC65).withValues(alpha: vortexOpacity * 0.35), // Verde Limão
            const Color(0xFFE53935).withValues(alpha: 0.0), // Borda transparente
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: maxVortexRadius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawCircle(center, maxVortexRadius, vortexGlow);

      // Partículas em espiral aglomerando no centro
      final particlePaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 16; i++) {
        final pAngle = swirlAngle + (i / 16) * 2 * math.pi;
        final pDist = maxVortexRadius * (1.0 - vortexProgress * 0.75) * (0.3 + (i % 5) * 0.15);
        final px = center.dx + math.cos(pAngle) * pDist;
        final py = center.dy + math.sin(pAngle) * pDist;

        particlePaint.color = streaks[i % streaks.length].color.withValues(alpha: vortexOpacity * 0.7);
        canvas.drawCircle(Offset(px, py), 3.0 + (i % 3) * 1.5, particlePaint);
      }
    }

    // 3. Flash e Shockwave Radiante no momento da formação da Maçã (t ~ 0.65 a 0.85)
    if (progress >= 0.65 && progress <= 0.88) {
      final burstT = ((progress - 0.65) / 0.23).clamp(0.0, 1.0);
      final burstRadius = 40.0 + burstT * 110.0;
      final burstOpacity = (1.0 - burstT).clamp(0.0, 1.0);

      final shockwavePaint = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: burstOpacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - burstT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, burstRadius, shockwavePaint);
    }
  }

  Offset _calculatePoint(
    Offset center,
    double maxRadius,
    ColorStreamStreak streak,
    double t,
  ) {
    // Ponto inicial nas bordas
    final startR = maxRadius * streak.startRadiusFactor;
    final startX = center.dx + math.cos(streak.startAngle) * startR;
    final startY = center.dy + math.sin(streak.startAngle) * startR;

    // Destino no centro (deslocado para o lobo respectivo da maçã)
    final targetX = center.dx + streak.targetCenterOffset.dx;
    final targetY = center.dy + streak.targetCenterOffset.dy;

    // Interpolação com onda senoidal para fluidez orgânica
    final linearX = startX + (targetX - startX) * t;
    final linearY = startY + (targetY - startY) * t;

    // Efeito de onda e espiral que intensifica e depois se acalma ao chegar no centro
    final waveEnvelope = math.sin(t * math.pi); // 0 no início e 0 no final
    final waveOffset = math.sin(t * math.pi * streak.waveFrequency) * streak.waveAmplitude * waveEnvelope;

    // Vetor perpendicular à direção de movimento
    final dx = targetX - startX;
    final dy = targetY - startY;
    final len = math.sqrt(dx * dx + dy * dy);
    final perpX = len > 0 ? -dy / len : 0.0;
    final perpY = len > 0 ? dx / len : 0.0;

    // Vórtice nos últimos 30% do percurso
    double swirlX = 0.0;
    double swirlY = 0.0;
    if (t > 0.65) {
      final swirlFactor = (t - 0.65) / 0.35;
      final swirlAngle = swirlFactor * math.pi * 1.5 * streak.swirlDirection;
      final swirlRadius = (1.0 - swirlFactor) * 25.0;
      swirlX = math.cos(swirlAngle) * swirlRadius;
      swirlY = math.sin(swirlAngle) * swirlRadius;
    }

    return Offset(
      linearX + perpX * waveOffset + swirlX,
      linearY + perpY * waveOffset + swirlY,
    );
  }

  @override
  bool shouldRepaint(covariant ColorStreamPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
