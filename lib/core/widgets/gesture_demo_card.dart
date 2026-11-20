import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

/// A self-playing demo of the transaction list gestures, built from a fake row
/// so it works before the user has any data.
///
/// Loop: swipe right (Edit) → swipe left (Trash) → long-press (Select).
/// Users can also drag the row themselves; it springs back and nothing is saved.
class GestureDemoCard extends StatefulWidget {
  const GestureDemoCard({super.key});

  @override
  State<GestureDemoCard> createState() => _GestureDemoCardState();
}

enum _DemoGesture { idle, edit, trash, select }

class _GestureDemoCardState extends State<GestureDemoCard> with TickerProviderStateMixin {
  static const _revealFraction = 0.34;

  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 7200))
    ..repeat();

  late final AnimationController _springBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Offset (in px) while the user is dragging or the row is springing back.
  double? _manualDx;
  double _springFrom = 0;

  @override
  void initState() {
    super.initState();
    _springBack.addListener(() {
      setState(() {
        _manualDx = _springFrom * (1 - Curves.easeOutCubic.transform(_springBack.value));
      });
    });
    _springBack.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _manualDx = null);
        _loop
          ..value = 0
          ..repeat();
      }
    });
  }

  @override
  void dispose() {
    _loop.dispose();
    _springBack.dispose();
    super.dispose();
  }

  // ── Scripted timeline (t = 0..1) ─────────────────────────────
  // Returns the row offset as a fraction of the width (-1..1).
  double _scriptedOffset(double t) {
    double ease(double from, double to, double a, double b) {
      final p = ((t - a) / (b - a)).clamp(0.0, 1.0);
      return from + (to - from) * Curves.easeInOutCubic.transform(p);
    }

    if (t < 0.08) return 0;
    if (t < 0.20) return ease(0, _revealFraction, 0.08, 0.20);
    if (t < 0.32) return _revealFraction;
    if (t < 0.40) return ease(_revealFraction, 0, 0.32, 0.40);
    if (t < 0.46) return 0;
    if (t < 0.58) return ease(0, -_revealFraction, 0.46, 0.58);
    if (t < 0.70) return -_revealFraction;
    if (t < 0.78) return ease(-_revealFraction, 0, 0.70, 0.78);
    return 0;
  }

  _DemoGesture _scriptedGesture(double t) {
    if (t >= 0.08 && t < 0.40) return _DemoGesture.edit;
    if (t >= 0.46 && t < 0.78) return _DemoGesture.trash;
    if (t >= 0.82 && t < 0.98) return _DemoGesture.select;
    return _DemoGesture.idle;
  }

  /// 0..1 strength of the long-press highlight.
  double _selectStrength(double t) {
    if (t < 0.82 || t >= 0.98) return 0;
    if (t < 0.86) return (t - 0.82) / 0.04;
    if (t > 0.94) return (0.98 - t) / 0.04;
    return 1;
  }

  // ── Manual drag ──────────────────────────────────────────────
  void _onDragStart(DragStartDetails _) {
    _loop.stop();
    _springBack.stop();
    setState(() => _manualDx = _manualDx ?? 0);
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    final max = width * _revealFraction * 1.15;
    setState(() => _manualDx = ((_manualDx ?? 0) + d.delta.dx).clamp(-max, max));
  }

  void _onDragEnd(DragEndDetails _) {
    _springFrom = _manualDx ?? 0;
    _springBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.warning.withValues(alpha: 0.22), const Color(0xFF0F172A)]
              : [AppColors.warning.withValues(alpha: 0.14), Colors.white],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.warning.withValues(alpha: isDark ? 0.35 : 0.25), width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = _loop.value;
              final isManual = _manualDx != null;
              final dx = isManual ? _manualDx! : _scriptedOffset(t) * width;
              final select = isManual ? 0.0 : _selectStrength(t);
              final gesture = isManual
                  ? (dx > 8 ? _DemoGesture.edit : (dx < -8 ? _DemoGesture.trash : _DemoGesture.idle))
                  : _scriptedGesture(t);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
                    onHorizontalDragEnd: _onDragEnd,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 68,
                        child: Stack(
                          children: [
                            Positioned.fill(child: _ActionBackground(isEdit: dx >= 0)),
                            Transform.translate(
                              offset: Offset(dx, 0),
                              child: Transform.scale(
                                scale: 1 - 0.03 * math.sin(select * math.pi / 2),
                                child: _FakeTransactionRow(isDark: isDark, selected: select),
                              ),
                            ),
                            if (!isManual && gesture != _DemoGesture.idle)
                              _FingerHint(gesture: gesture, rowDx: dx, width: width, select: select),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GestureCaption(gesture: gesture),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ActionBackground extends StatelessWidget {
  final bool isEdit;

  const _ActionBackground({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: isEdit ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: isEdit ? AppColors.primary : AppColors.expense,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isEdit
            ? const [
                Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'Edit',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ]
            : const [
                Text(
                  'Trash',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 6),
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              ],
      ),
    );
  }
}

class _FakeTransactionRow extends StatelessWidget {
  final bool isDark;
  final double selected; // 0..1

  const _FakeTransactionRow({required this.isDark, required this.selected});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color.lerp(base, Color.alphaBlend(AppColors.primary.withValues(alpha: 0.15), base), selected),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color.lerp(border, AppColors.primary, selected)!, width: 1 + 0.5 * selected),
      ),
      child: Row(
        children: [
          if (selected > 0.5)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
            ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_cafe_rounded, color: Color(0xFFF97316), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morning Coffee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(height: 2),
                Text('Cash  •  Today', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '-${CurrencyFormatter.format(250)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.expense),
          ),
        ],
      ),
    );
  }
}

/// A translucent "fingertip" that follows the scripted gesture.
class _FingerHint extends StatelessWidget {
  final _DemoGesture gesture;
  final double rowDx;
  final double width;
  final double select;

  const _FingerHint({required this.gesture, required this.rowDx, required this.width, required this.select});

  @override
  Widget build(BuildContext context) {
    final double left;
    final double size;
    if (gesture == _DemoGesture.select) {
      left = width * 0.45;
      size = 34 + 10 * select; // grows while "pressing"
    } else {
      left = width * 0.5 + rowDx - 17;
      size = 34;
    }
    return Positioned(
      left: left,
      top: (68 - size) / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
          ),
        ),
      ),
    );
  }
}

class _GestureCaption extends StatelessWidget {
  final _DemoGesture gesture;

  const _GestureCaption({required this.gesture});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = switch (gesture) {
      _DemoGesture.edit => (Icons.swipe_right_rounded, 'Swipe right to edit', AppColors.primary),
      _DemoGesture.trash => (Icons.swipe_left_rounded, 'Swipe left to move to Recycle Bin', AppColors.expense),
      _DemoGesture.select => (Icons.touch_app_rounded, 'Long-press to select multiple', AppColors.transfer),
      _DemoGesture.idle => (Icons.pan_tool_alt_rounded, 'Try it: drag the row left or right', Colors.grey),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Row(
        key: ValueKey(gesture),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
