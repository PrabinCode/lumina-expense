import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Emil Kowalski signature tactile press wrapper.
///
/// Compresses slightly (default [pressedScale] = 0.96) on touch-down with
/// instant feedback and an immediate haptic click, then rebounds with
/// spring physics ([Curves.easeOutBack]) on release.
class Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const Bouncy({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Fast depression (85ms) + physical spring overshoot on release (150ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 85),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _downTimestamp = 0;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _downTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _downTimestamp;
    const minHoldMs = 85;
    if (elapsed < minHoldMs) {
      Future.delayed(Duration(milliseconds: minHoldMs - elapsed), () {
        if (mounted) _controller.reverse();
      });
    } else {
      _controller.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleLongPress() {
    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      behavior: widget.behavior,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
