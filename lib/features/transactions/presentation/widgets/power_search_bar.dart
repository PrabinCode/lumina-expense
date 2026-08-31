import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PowerSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onClear;
  final String hintText;

  const PowerSearchBar({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.onClear,
    this.hintText = 'Search transactions (e.g. cat:Food amount:>50)',
  });

  @override
  State<PowerSearchBar> createState() => _PowerSearchBarState();
}

class _PowerSearchBarState extends State<PowerSearchBar> {
  late TextEditingController _controller;
  bool _showSyntaxGuide = false;

  final List<String> _quickTokens = [
    'cat:Groceries',
    'amount:>50',
    'type:expense',
    'type:income',
    'tag:',
    'acc:',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant PowerSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertToken(String token) {
    final currentText = _controller.text.trim();
    final newText = currentText.isEmpty ? token : '$currentText $token';
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
    widget.onQueryChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onQueryChanged,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onQueryChanged('');
                    widget.onClear?.call();
                  },
                ),
              IconButton(
                icon: Icon(
                  _showSyntaxGuide ? Icons.help_rounded : Icons.help_outline_rounded,
                  size: 18,
                  color: _showSyntaxGuide ? AppColors.primary : null,
                ),
                tooltip: 'Search Syntax Guide',
                onPressed: () => setState(() => _showSyntaxGuide = !_showSyntaxGuide),
              ),
            ],
          ),
        ),
        if (_showSyntaxGuide) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Advanced Power Query Syntax:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),

                const SizedBox(height: 4),
                const Text(
                  '• cat:Dining (filter category)  • acc:Cash (filter account)\n'
                  '• amount:>50, <=100  • date:2026-08\n'
                  '• tag:trip  • -tag:work (negate/exclude)\n'
                  '• cat:Dining && amount:>20 (AND / OR logic)',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickTokens.map((token) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(token, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  onPressed: () => _insertToken(token),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
