import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlidingPillSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color activeColor;

  const SlidingPillSegment({
    required this.value,
    required this.label,
    this.icon,
    required this.activeColor,
  });
}

/// Emil Kowalski fluid sliding pill segmented control.
///
/// Rather than discrete tabs flashing on/off, an active indicator pill
/// physically slides across segments with spring-like cubic interpolation.
class SlidingPillControl<T> extends StatelessWidget {
  final List<SlidingPillSegment<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;

  const SlidingPillControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = segments.indexWhere((s) => s.value == selectedValue);
    final validIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final activeSegment = segments[validIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = segments.length;
        if (count == 0) return const SizedBox.shrink();

        // 4px internal padding on each side
        const horizontalPadding = 4.0;
        final availableWidth = totalWidth - (horizontalPadding * 2);
        final itemWidth = availableWidth / count;

        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161F30) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Gliding pill indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: validIndex * itemWidth,
                width: itemWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeSegment.activeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeSegment.activeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Segment text & icon triggers
              Row(
                children: segments.map((seg) {
                  final isSelected = seg.value == selectedValue;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (seg.value != selectedValue) {
                          HapticFeedback.selectionClick();
                          onValueChanged(seg.value);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (seg.icon != null) ...[
                              Icon(
                                seg.icon,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                            ],
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              child: Text(seg.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
