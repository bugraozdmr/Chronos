import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_screen.dart';

/// Animated splash for Chronos.
///
/// No app icon — instead a minimal chronometer dial whose hand sweeps the
/// dial and "lights" the tick marks as it passes, in the app's monochrome
/// style. Fades out into [MainScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _sweep;

  late final Animation<double> _dialScale;
  late final Animation<double> _dialFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _ruleWidth;
  late final Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    // Dial fades in first and slightly scales up.
    _dialFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _dialScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );

    // CHRONOS letters stagger in.
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic)),
    );

    // Rule expands from center.
    _ruleWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic)),
    );

    // Tagline fades in.
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.9, curve: Curves.easeOut)),
    );

    // Everything fades out at the very end.
    _contentFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.85, 1.0, curve: Curves.easeIn)),
    );
    
    _sweep.addStatusListener((status) {
      if (status == AnimationStatus.completed) _sweep.forward(from: 0);
    });

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _sweep.repeat();
    });

    _controller.forward().whenComplete(_navigateAway);
  }

  void _navigateAway() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _sweep.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final fadedInk = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Soft radial glow behind the dial.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: isDark
                      ? [
                          const Color(0xFF18181B).withOpacity(0.9),
                          Colors.transparent,
                        ]
                      : [
                          Colors.black.withOpacity(0.045),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _contentFade,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                  // Dial
                  AnimatedBuilder(
                    animation: Listenable.merge([_dialScale, _dialFade, _sweep]),
                    builder: (context, _) {
                      return Opacity(
                        opacity: _dialFade.value,
                        child: Transform.scale(
                          scale: _dialScale.value,
                          child: CustomPaint(
                            size: const Size(200, 200),
                            painter: _ChronosDialPainter(
                              color: ink,
                              bgColor: Theme.of(context).scaffoldBackgroundColor,
                              sweep: _sweep.value,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 44),

                  // Wordmark: CHRONOS, letters staggered in.
                  AnimatedBuilder(
                    animation: _titleFade,
                    builder: (context, _) {
                      const word = 'CHRONOS';
                      const n = word.length;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(n, (i) {
                          final t = ((_titleFade.value * n) - i).clamp(0.0, 1.0);
                          return Padding(
                            padding: EdgeInsets.only(right: i < n - 1 ? 10.0 : 0.0),
                            child: Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - t)),
                                child: Text(
                                  word[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Expanding rule
                  AnimatedBuilder(
                    animation: _ruleWidth,
                    builder: (context, _) {
                      return Container(
                        width: 52 * _ruleWidth.value,
                        height: 2,
                        decoration: BoxDecoration(
                          color: ink.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'EVERY SECOND COUNTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                        color: fadedInk,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChronosDialPainter extends CustomPainter {
  final Color color;
  final Color bgColor;
  final double sweep;

  const _ChronosDialPainter({required this.color, required this.bgColor, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Static outer reference ring.
    line
      ..color = color.withOpacity(0.14)
      ..strokeWidth = radius * 0.02;
    canvas.drawCircle(center, radius - radius * 0.06, line);

    final handAngle = sweep * 2 * math.pi - math.pi / 2;
    const tickCount = 60;
    const traceWindow = 0.20;

    // Ticks light up as the hand passes over them.
    for (var i = 0; i < tickCount; i++) {
      final a = (i / tickCount) * 2 * math.pi - math.pi / 2;
      final behind = ((handAngle - a) % (2 * math.pi)) / (2 * math.pi);
      final intensity =
          ((1 - behind / traceWindow).clamp(0.0, 1.0) * 0.9 + 0.10).clamp(0.0, 1.0);

      final major = i % 5 == 0;
      final inner = radius * (major ? 0.80 : 0.86);
      final outer = radius - radius * 0.06;

      line
        ..color = color.withOpacity(intensity * (major ? 0.85 : 0.55))
        ..strokeWidth = radius * (major ? 0.030 : 0.016);

      canvas.drawLine(
        Offset(center.dx + math.cos(a) * inner, center.dy + math.sin(a) * inner),
        Offset(center.dx + math.cos(a) * outer, center.dy + math.sin(a) * outer),
        line,
      );
    }

    // Trailing arc behind the hand (the recently "tracked" span).
    final arcPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.55),
      handAngle - math.pi / 2,
      traceWindow * 2 * math.pi,
      false,
      arcPaint,
    );

    // The hand.
    final handPaint = Paint()
      ..color = color
      ..strokeWidth = radius * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx + math.cos(handAngle) * radius * 0.26,
          center.dy + math.sin(handAngle) * radius * 0.26),
      Offset(center.dx + math.cos(handAngle) * radius * 0.84,
          center.dy + math.sin(handAngle) * radius * 0.84),
      handPaint,
    );

    // Counter-rotating inner dot ring.
    final innerRotation = -sweep * 2 * math.pi * 0.75;
    final dotPaint = Paint()..color = color.withOpacity(0.30);
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * math.pi + innerRotation;
      canvas.drawCircle(
        Offset(center.dx + math.cos(a) * radius * 0.38, center.dy + math.sin(a) * radius * 0.38),
        radius * 0.018,
        dotPaint,
      );
    }

    // Center pivot.
    canvas.drawCircle(center, radius * 0.07, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius * 0.028,
      Paint()..color = bgColor,
    );
  }

  @override
  bool shouldRepaint(_ChronosDialPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.bgColor != bgColor || oldDelegate.sweep != sweep;
}