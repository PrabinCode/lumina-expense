import 'dart:async';
import 'dart:ui' show FontFeature, lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class NumKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final Color? accentColor;

  const NumKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onDelete,
    required this.onClear,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _TactileKeypadButton(text: '1', onTap: () => onKeyPressed('1'), accentColor: accent),
            _TactileKeypadButton(text: '2', onTap: () => onKeyPressed('2'), accentColor: accent),
            _TactileKeypadButton(text: '3', onTap: () => onKeyPressed('3'), accentColor: accent),
          ],
        ),
        Row(
          children: [
            _TactileKeypadButton(text: '4', onTap: () => onKeyPressed('4'), accentColor: accent),
            _TactileKeypadButton(text: '5', onTap: () => onKeyPressed('5'), accentColor: accent),
            _TactileKeypadButton(text: '6', onTap: () => onKeyPressed('6'), accentColor: accent),
          ],
        ),
        Row(
          children: [
            _TactileKeypadButton(text: '7', onTap: () => onKeyPressed('7'), accentColor: accent),
            _TactileKeypadButton(text: '8', onTap: () => onKeyPressed('8'), accentColor: accent),
            _TactileKeypadButton(text: '9', onTap: () => onKeyPressed('9'), accentColor: accent),
          ],
        ),
        Row(
          children: [
            _TactileKeypadButton(text: '.', onTap: () => onKeyPressed('.'), accentColor: accent),
            _TactileKeypadButton(text: '0', onTap: () => onKeyPressed('0'), accentColor: accent),
            _TactileKeypadButton(
              icon: Icons.backspace_rounded,
              onTap: onDelete,
              onLongPress: onClear,
              accentColor: accent,
            ),
          ],
        ),
      ],
    );
  }
}

class _TactileKeypadButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color accentColor;

  const _TactileKeypadButton({
    this.text,
    this.icon,
    required this.onTap,
    this.onLongPress,
    required this.accentColor,
  });

  @override
  State<_TactileKeypadButton> createState() => _TactileKeypadButtonState();
}

class _TactileKeypadButtonState extends State<_TactileKeypadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _highlightAnimation;

  Timer? _longPressTimer;
  int _downTimestamp = 0;
  Offset _startPosition = Offset.zero;
  bool _isPressed = false;
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    // Fast tactile compression (70ms) and spring overshoot rebound (140ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 140),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );

    _highlightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
      reverseCurve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _downTimestamp = DateTime.now().millisecondsSinceEpoch;
    _startPosition = event.position;
    _isPressed = true;
    _longPressTriggered = false;

    if (widget.icon != null) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
    _controller.forward();

    if (widget.onLongPress != null) {
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 400), () {
        if (_isPressed && mounted) {
          _longPressTriggered = true;
          HapticFeedback.mediumImpact();
          widget.onLongPress!();
        }
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isPressed) return;
    final distance = (event.position - _startPosition).distance;
    // Cancel press action if finger is dragging to scroll
    if (distance > 18.0) {
      _cancelPress();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    if (!_isPressed) return;

    final box = context.findRenderObject() as RenderBox?;
    final isInside = box != null && box.paintBounds.contains(event.localPosition);

    if (!_longPressTriggered && isInside) {
      widget.onTap();
    }

    // Guarantee minimum press duration so quick taps always show the full click animation
    final elapsed = DateTime.now().millisecondsSinceEpoch - _downTimestamp;
    const minHoldMs = 85;
    if (elapsed < minHoldMs) {
      Future.delayed(Duration(milliseconds: minHoldMs - elapsed), () {
        if (mounted) {
          _isPressed = false;
          _controller.reverse();
        }
      });
    } else {
      _isPressed = false;
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelPress();
  }

  void _cancelPress() {
    _longPressTimer?.cancel();
    _isPressed = false;
    _longPressTriggered = false;
    if (mounted) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor;

    final idleBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textBaseColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.5),
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final hVal = _highlightAnimation.value;
                final scale = _scaleAnimation.value;

                final activeBg = Color.lerp(
                  idleBg,
                  accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  hVal,
                )!;

                final activeBorderColor = Color.lerp(
                  idleBorder,
                  accent.withValues(alpha: isDark ? 0.65 : 0.50),
                  hVal,
                )!;

                final borderWidth = lerpDouble(1.0, 1.6, hVal)!;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeBorderColor,
                        width: borderWidth,
                      ),
                      boxShadow: hVal > 0.05
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: (isDark ? 0.30 : 0.20) * hVal),
                                blurRadius: 10 * hVal,
                                spreadRadius: 0.5 * hVal,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(
                            isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.70),
                            accent.withValues(alpha: isDark ? 0.28 : 0.20),
                            hVal,
                          )!,
                          Color.lerp(
                            idleBg,
                            accent.withValues(alpha: isDark ? 0.16 : 0.10),
                            hVal,
                          )!,
                        ],
                      ),
                    ),
                    child: widget.text != null
                        ? Text(
                            widget.text!,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                              color: Color.lerp(
                                textBaseColor,
                                accent,
                                hVal * 0.4,
                              ),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          )
                        : Icon(
                            widget.icon,
                            size: 21,
                            color: Color.lerp(
                              textBaseColor,
                              accent,
                              hVal * 0.4,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
