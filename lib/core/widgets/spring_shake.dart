import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Emil Kowalski decaying spring shake widget for validation error feedback.
///
/// Simulates a damped mechanical spring oscillator:
///   offset(t) = A * e^(-decay * t) * sin(freq * pi * t)
class SpringShake extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;

  const SpringShake({
    super.key,
    required this.child,
    this.amplitude = 12.0,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<SpringShake> createState() => SpringShakeState();
}

class SpringShakeState extends State<SpringShake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triggers the spring oscillation and haptic shock.
  void shake() {
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Damped harmonic oscillation
        final offset = widget.amplitude * exp(-4.5 * t) * sin(6.0 * pi * t);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
