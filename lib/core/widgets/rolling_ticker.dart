import 'package:flutter/material.dart';

/// Emil Kowalski mechanical odometer ticker widget for numeric values.
///
/// Features:
/// - Guarantees [FontFeature.tabularFigures] to prevent horizontal character jitter.
/// - Animates individual digits vertically with smooth cubic/spring deceleration.
/// - Handles symbols, commas, decimals, and privacy masks gracefully.
class RollingTicker extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const RollingTicker({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style.copyWith(
      fontFeatures: [
        ...?style.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < text.length; i++)
          _buildChar(text[i], effectiveStyle),
      ],
    );
  }

  Widget _buildChar(String char, TextStyle effectiveStyle) {
    final digit = int.tryParse(char);
    if (digit == null) {
      // Non-digit character (currency symbol, comma, decimal, minus, mask)
      return Text(char, style: effectiveStyle);
    }

    return _RollingDigitSlot(
      digit: digit,
      style: effectiveStyle,
      duration: duration,
    );
  }
}

class _RollingDigitSlot extends StatelessWidget {
  final int digit;
  final TextStyle style;
  final Duration duration;

  const _RollingDigitSlot({
    required this.digit,
    required this.style,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        final inAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.45),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return ClipRect(
          child: SlideTransition(
            position: inAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        '$digit',
        key: ValueKey<int>(digit),
        style: style,
      ),
    );
  }
}
