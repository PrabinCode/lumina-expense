import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SonnerType { success, error, warning, info, neutral }

class _SonnerEntry {
  final String id;
  final String title;
  final String? description;
  final SonnerType type;
  final Duration duration;
  final VoidCallback? onUndo;
  final String undoLabel;
  final DateTime createdAt;

  _SonnerEntry({
    required this.id,
    required this.title,
    this.description,
    this.type = SonnerType.neutral,
    this.duration = const Duration(seconds: 4),
    this.onUndo,
    this.undoLabel = 'UNDO',
  }) : createdAt = DateTime.now();
}

/// Emil Kowalski "Sonner" floating stacked toast notification engine.
///
/// Provides top-floating stacked cards with 3D depth, gesture swipe dismissal,
/// and interactive inline actions (e.g., Undo).
class Sonner {
  static final GlobalKey<SonnerToastHostState> hostKey = GlobalKey<SonnerToastHostState>();

  static void success(String title, {String? description, VoidCallback? onUndo, String undoLabel = 'UNDO', Duration duration = const Duration(seconds: 4)}) {
    _show(title: title, description: description, type: SonnerType.success, onUndo: onUndo, undoLabel: undoLabel, duration: duration);
  }

  static void error(String title, {String? description, Duration duration = const Duration(seconds: 4)}) {
    _show(title: title, description: description, type: SonnerType.error, duration: duration);
  }

  static void warning(String title, {String? description, Duration duration = const Duration(seconds: 4)}) {
    _show(title: title, description: description, type: SonnerType.warning, duration: duration);
  }

  static void info(String title, {String? description, Duration duration = const Duration(seconds: 4)}) {
    _show(title: title, description: description, type: SonnerType.info, duration: duration);
  }

  static void _show({
    required String title,
    String? description,
    required SonnerType type,
    VoidCallback? onUndo,
    String undoLabel = 'UNDO',
    Duration duration = const Duration(seconds: 4),
  }) {
    HapticFeedback.lightImpact();
    hostKey.currentState?.showToast(
      title: title,
      description: description,
      type: type,
      onUndo: onUndo,
      undoLabel: undoLabel,
      duration: duration,
    );
  }
}

class SonnerToastHost extends StatefulWidget {
  final Widget child;

  SonnerToastHost({Key? key, required this.child}) : super(key: key ?? Sonner.hostKey);

  @override
  State<SonnerToastHost> createState() => SonnerToastHostState();
}

class SonnerToastHostState extends State<SonnerToastHost> {
  final List<_SonnerEntry> _toasts = [];

  void showToast({
    required String title,
    String? description,
    required SonnerType type,
    VoidCallback? onUndo,
    String undoLabel = 'UNDO',
    Duration duration = const Duration(seconds: 4),
  }) {
    final entry = _SonnerEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      type: type,
      onUndo: onUndo,
      undoLabel: undoLabel,
      duration: duration,
    );

    setState(() {
      _toasts.insert(0, entry);
      if (_toasts.length > 3) {
        _toasts.removeLast();
      }
    });

    Timer(entry.duration, () {
      if (mounted) {
        removeToast(entry.id);
      }
    });
  }

  void removeToast(String id) {
    setState(() {
      _toasts.removeWhere((t) => t.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        widget.child,
        if (_toasts.isNotEmpty)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  for (int i = _toasts.length - 1; i >= 0; i--)
                    _buildToastCard(_toasts[i], i, isDark),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToastCard(_SonnerEntry toast, int index, bool isDark) {
    // Emil Kowalski 3D cascade calculations
    final scale = 1.0 - (index * 0.06);
    final translateY = index * -8.0;
    final opacity = (1.0 - (index * 0.22)).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, translateY, 0),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: opacity,
          child: Dismissible(
            key: Key(toast.id),
            direction: DismissDirection.up,
            onDismissed: (_) => removeToast(toast.id),
            child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildIcon(toast.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toast.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (toast.description != null && toast.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          toast.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (toast.onUndo != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      toast.onUndo!();
                      removeToast(toast.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        toast.undoLabel,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(SonnerType type) {
    switch (type) {
      case SonnerType.success:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16),
        );
      case SonnerType.error:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
        );
      case SonnerType.warning:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
        );
      case SonnerType.info:
      case SonnerType.neutral:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 16),
        );
    }
  }
}
