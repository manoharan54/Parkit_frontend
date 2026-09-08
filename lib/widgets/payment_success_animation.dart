import 'package:flutter/material.dart';

import '../styles.dart';

/// Composed payment-success animation inside a fixed stage.
///
/// Layout contract (prevents all "jumping layout" issues):
/// - Fixed container: 180x180 on phones, 220x220 on tablets, never >240.
/// - Only opacity, scale and checkmark drawing are animated — no rotation,
///   bounce, spring physics, expanding containers, AnimatedSize or Hero.
/// - Everything animates with [Transform.scale] around the exact center,
///   clipped by [ClipRect], so parent size never changes and surrounding
///   text/buttons never move.
class PaymentSuccessAnimation extends StatefulWidget {
  const PaymentSuccessAnimation({super.key});

  /// Fixed stage size by device class (capped at 240).
  static double stageSize(BuildContext context) {
    final size = AppResponsive.isTablet(context) ? 220.0 : 180.0;
    return size > 240.0 ? 240.0 : size;
  }

  @override
  State<PaymentSuccessAnimation> createState() =>
      _PaymentSuccessAnimationState();
}

class _PaymentSuccessAnimationState
    extends State<PaymentSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleOpacity;
  late final Animation<double> _circleScale;
  late final Animation<double> _checkProgress;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Circle fades in while scaling 0.8 -> 1.0 (linear ease-out only).
    _circleOpacity = _tween(0.0, 1.0, const Interval(0.0, 0.3));
    _circleScale = _tween(0.8, 1.0, const Interval(0.0, 0.45));
    // Checkmark draws itself once the circle is nearly formed.
    _checkProgress = _tween(0.0, 1.0, const Interval(0.35, 0.75));
    // Single soft pulse ring: 1.0 -> 1.15 while fading out.
    _pulseScale = _tween(1.0, 1.15, const Interval(0.3, 1.0));
    _pulseOpacity = Tween(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
    _controller.forward();
  }

  Animation<double> _tween(
          double begin, double end, Interval interval) =>
      Tween(begin: begin, end: end).animate(
        CurvedAnimation(parent: _controller, curve: interval),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = PaymentSuccessAnimation.stageSize(context);
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        // Hard clip: nothing may paint outside the fixed stage.
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring behind the circle.
                  Opacity(
                    opacity: _pulseOpacity.value,
                    child: Transform.scale(
                      scale: _pulseScale.value,
                      alignment: Alignment.center,
                      child: Container(
                        width: size * 0.62,
                        height: size * 0.62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Solid circle scaling 0.8 -> 1.0.
                  Opacity(
                    opacity: _circleOpacity.value,
                    child: Transform.scale(
                      scale: _circleScale.value,
                      alignment: Alignment.center,
                      child: Container(
                        width: size * 0.56,
                        height: size * 0.56,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // White checkmark drawing itself on top.
                  SizedBox(
                    width: size * 0.56,
                    height: size * 0.56,
                    child: CustomPaint(
                      painter: _CheckPainter(
                        progress: _checkProgress.value,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Draws the check stroke progressively (0.0 -> 1.0 of the path length).
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.32, size.height * 0.54)
      ..lineTo(size.width * 0.46, size.height * 0.68)
      ..lineTo(size.width * 0.70, size.height * 0.36);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
