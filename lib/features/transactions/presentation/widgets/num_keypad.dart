import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class NumKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const NumKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _KeypadButton(text: '1', onTap: () => onKeyPressed('1')),
            _KeypadButton(text: '2', onTap: () => onKeyPressed('2')),
            _KeypadButton(text: '3', onTap: () => onKeyPressed('3')),
          ],
        ),
        Row(
          children: [
            _KeypadButton(text: '4', onTap: () => onKeyPressed('4')),
            _KeypadButton(text: '5', onTap: () => onKeyPressed('5')),
            _KeypadButton(text: '6', onTap: () => onKeyPressed('6')),
          ],
        ),
        Row(
          children: [
            _KeypadButton(text: '7', onTap: () => onKeyPressed('7')),
            _KeypadButton(text: '8', onTap: () => onKeyPressed('8')),
            _KeypadButton(text: '9', onTap: () => onKeyPressed('9')),
          ],
        ),
        Row(
          children: [
            _KeypadButton(text: '.', onTap: () => onKeyPressed('.')),
            _KeypadButton(text: '0', onTap: () => onKeyPressed('0')),
            _KeypadIconButton(
              icon: Icons.backspace_outlined,
              onTap: onDelete,
              onLongPress: onClear,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _KeypadButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _KeypadIconButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Icon(
                icon,
                size: 20,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
