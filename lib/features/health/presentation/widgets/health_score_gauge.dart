import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/financial_health_service.dart';

class HealthScoreGauge extends StatefulWidget {
  final double score;
  final String? grade;
  final Color? gradeColor;
  final HealthTier? tier;
  final double size;
  final bool showTierBadge;
  final bool showSubtext;

  const HealthScoreGauge({
    super.key,
    required this.score,
    this.grade,
    this.gradeColor,
    this.tier,
    this.size = 200.0,
    this.showTierBadge = true,
    this.showSubtext = true,
  });

  @override
  State<HealthScoreGauge> createState() => _HealthScoreGaugeState();
}

class _HealthScoreGaugeState extends State<HealthScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _animation = Tween<double>(begin: 0.0, end: widget.score.clamp(0.0, 100.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(HealthScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.score.clamp(0.0, 100.0),
      ).animate(
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
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final effectiveColor = widget.tier?.color ?? widget.gradeColor ?? AppColors.primary;
    final effectiveLabel = widget.tier != null
        ? '${widget.tier!.icon} ${widget.tier!.label}'
        : (widget.grade ?? 'Health');

    final isCompact = widget.size < 120;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentScore = _animation.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _GaugePainter(
              score: currentScore,
              activeColor: effectiveColor,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              tickColor: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.18),
              showTicks: !isCompact,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Score Value
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currentScore.toInt().toString(),
                          style: TextStyle(
                            fontSize: isCompact ? widget.size * 0.32 : widget.size * 0.24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            color: textColor,
                            height: 1.0,
                          ),
                        ),
                        if (!isCompact && widget.showSubtext) ...[
                          const SizedBox(width: 2),
                          Text(
                            '/100',
                            style: TextStyle(
                              fontSize: widget.size * 0.08,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Tier / Grade Badge
                    if (widget.showTierBadge && !isCompact) ...[
                      SizedBox(height: widget.size * 0.04),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.size * 0.07,
                          vertical: widget.size * 0.025,
                        ),
                        decoration: BoxDecoration(
                          color: effectiveColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: effectiveColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          effectiveLabel,
                          style: TextStyle(
                            fontSize: widget.size * 0.075,
                            fontWeight: FontWeight.w700,
                            color: effectiveColor,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],

                    if (isCompact && widget.showTierBadge) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.tier?.label ?? widget.grade ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.size * 0.13,
                          fontWeight: FontWeight.w700,
                          color: effectiveColor,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
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
  final Color activeColor;
  final Color backgroundColor;
  final Color tickColor;
  final bool showTicks;

  _GaugePainter({
    required this.score,
    required this.activeColor,
    required this.backgroundColor,
    required this.tickColor,
    required this.showTicks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.085;
    final radius = (size.width - strokeWidth) / 2;

    // 240-degree arc centered from 150 deg (bottom-left) to 390 deg (bottom-right)
    const startAngle = 150 * (math.pi / 180);
    const sweepAngle = 240 * (math.pi / 180);

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Draw milestone tick markers (45, 60, 75, 90)
    if (showTicks) {
      final tickPaint = Paint()
        ..color = tickColor
        ..style = PaintingStyle.fill;

      final milestones = [0.45, 0.60, 0.75, 0.90];
      for (final ratio in milestones) {
        final angle = startAngle + (ratio * sweepAngle);
        final tickRadius = radius;
        final x = center.dx + tickRadius * math.cos(angle);
        final y = center.dy + tickRadius * math.sin(angle);
        canvas.drawCircle(Offset(x, y), strokeWidth * 0.16, tickPaint);
      }
    }

    // Active progress arc
    if (score > 0) {
      final scoreRatio = (score / 100.0).clamp(0.0, 1.0);
      final activeSweep = scoreRatio * sweepAngle;

      // Dynamic multi-stop gradient matching financial tiers
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          Color(0xFFEF4444), // At risk (Red)
          Color(0xFFF59E0B), // Needs Attention (Amber)
          Color(0xFF3B82F6), // Fair (Blue)
          Color(0xFF14B8A6), // Strong (Teal)
          Color(0xFF10B981), // Thriving (Emerald)
        ],
        stops: const [0.0, 0.45, 0.60, 0.75, 1.0],
        transform: GradientRotation(startAngle - math.pi / 2),
      );

      final activePaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius + strokeWidth),
        )
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );

      // Draw subtle luminous cap indicator
      final endAngle = startAngle + activeSweep;
      final capX = center.dx + radius * math.cos(endAngle);
      final capY = center.dy + radius * math.sin(endAngle);

      final capGlowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(capX, capY), strokeWidth * 0.45, capGlowPaint);

      final capDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(capX, capY), strokeWidth * 0.22, capDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.tickColor != tickColor;
  }
}
