import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';

class HealthScoreGauge extends StatefulWidget {
  final double score;
  final String grade;
  final Color gradeColor;
  final double size;

  const HealthScoreGauge({
    super.key,
    required this.score,
    required this.grade,
    required this.gradeColor,
    this.size = 200.0,
  });

  @override
  State<HealthScoreGauge> createState() => _HealthScoreGaugeState();
}

class _HealthScoreGaugeState extends State<HealthScoreGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = Tween<double>(begin: 0.0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }
  
  @override
  void didUpdateWidget(HealthScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: _animation.value, end: widget.score).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _GaugePainter(
              score: _animation.value,
              gradeColor: widget.gradeColor,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _animation.value.toInt().toString(),
                    style: TextStyle(
                      fontSize: widget.size * 0.25,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.gradeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.grade,
                      style: TextStyle(
                        fontSize: widget.size * 0.1,
                        fontWeight: FontWeight.w600,
                        color: widget.gradeColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color gradeColor;
  final Color backgroundColor;

  _GaugePainter({
    required this.score,
    required this.gradeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = size.width * 0.08;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw background arc (240 degrees)
    const startAngle = 150 * (math.pi / 180);
    const sweepAngle = 240 * (math.pi / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Create gradient
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        Color(0xFFDC2626), // F
        Color(0xFFF59E0B), // C
        Color(0xFF10B981), // A
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(startAngle - math.pi / 2), // Rotate to match arc start
    );

    // Draw foreground arc
    final foregroundPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final scoreSweepAngle = (score / 100) * sweepAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      scoreSweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.gradeColor != gradeColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
