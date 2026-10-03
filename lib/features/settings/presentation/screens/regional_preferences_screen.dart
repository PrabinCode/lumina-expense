import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_preferences_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_formatter.dart';

class RegionalPreferencesScreen extends ConsumerWidget {
  const RegionalPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final activeCurrency = ref.watch(currencyProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional & Formatting'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Section 1: Number & Currency Formatting ───
              _buildSectionHeader('Number & Currency Formatting', Icons.monetization_on_outlined),
              const SizedBox(height: 10),

              _buildGroupedCard(
                isDark: isDark,
                children: [
                  // Number Grouping Style
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.format_list_numbered_rounded, AppColors.primary),
                    title: const Text('Number Grouping', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      prefs.numberGrouping == AppNumberGrouping.southAsian
                          ? 'South Asian / Nepali (12,34,56,789)'
                          : 'International (123,456,789)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showNumberGroupingSheet(context, prefs, notifier),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // Currency Symbol Placement
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.currency_exchange_rounded, const Color(0xFF10B981)),
                    title: const Text('Symbol Placement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      prefs.currencyPosition == AppCurrencyPosition.prefix
                          ? 'Before Amount (${activeCurrency.symbol} 1,000)'
                          : 'After Amount (1,000 ${activeCurrency.symbol})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showCurrencyPositionSheet(context, prefs, notifier, activeCurrency),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // Decimal Handling
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.straighten_rounded, const Color(0xFFF59E0B)),
                    title: const Text('Decimal Display', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${prefs.decimalMode.label} (${prefs.decimalMode.example})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showDecimalModeSheet(context, prefs, notifier),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── Section 2: Date & Time Display ───
              _buildSectionHeader('Date & Time Display', Icons.calendar_today_outlined),
              const SizedBox(height: 10),

              _buildGroupedCard(
                isDark: isDark,
                children: [
                  // Date Format
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.calendar_month_outlined, const Color(0xFF6366F1)),
                    title: const Text('Date Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${prefs.dateFormat.label}  •  ${AppDateFormatter.formatDate(now, format: prefs.dateFormat)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showDateFormatSheet(context, prefs, notifier, now),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // Time Format
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.access_time_rounded, const Color(0xFF8B5CF6)),
                    title: const Text('Time Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${prefs.timeFormat.label}  •  ${AppDateFormatter.formatTime(now, format: prefs.timeFormat)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showTimeFormatSheet(context, prefs, notifier, now),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // First Day of Week
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.today_rounded, const Color(0xFF06B6D4)),
                    title: const Text('First Day of Week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      prefs.firstDayOfWeek == DateTime.sunday ? 'Sunday (Standard in Nepal / US)' : 'Monday (ISO standard)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showFirstDaySheet(context, prefs, notifier),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── Section 3: Receipt OCR & Scanner Settings ───
              _buildSectionHeader('Receipt OCR & Scanner', Icons.document_scanner_outlined),
              const SizedBox(height: 10),

              _buildGroupedCard(
                isDark: isDark,
                children: [
                  // OCR Date Interpretation
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _buildLeadingIcon(Icons.find_in_page_outlined, const Color(0xFFEC4899)),
                    title: const Text('Ambiguous Date Parsing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      prefs.ocrDateFormat == OcrDateFormatStrategy.smartProximity
                          ? 'Smart Proximity (Recommended)'
                          : prefs.ocrDateFormat.label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: () => _showOcrDateStrategySheet(context, prefs, notifier),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // Scan Items into Note & Remarks
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: _buildLeadingIcon(Icons.edit_note_rounded, const Color(0xFF3B82F6)),
                    title: const Text('Scan Items into Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                      'Auto-fill Note & Remarks with item descriptions and quantities from receipts',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: prefs.ocrScanNotes,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) => notifier.setOcrScanNotes(val),
                  ),

                  Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder, indent: 56),

                  // Auto-suggest Category
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: _buildLeadingIcon(Icons.auto_awesome_rounded, const Color(0xFF10B981)),
                    title: const Text('Auto-suggest Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                      'Automatically infer category (Food, Groceries, etc.) from receipt merchant or text',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: prefs.ocrAutoCategory,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) => notifier.setOcrAutoCategory(val),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard({required bool isDark, required List<Widget> children}) {
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLeadingIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showNumberGroupingSheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
  ) {
    _showSelectorBottomSheet<AppNumberGrouping>(
      context: context,
      title: 'Number Grouping',
      subtitle: 'Choose how numbers and currency values are grouped',
      icon: Icons.format_list_numbered_rounded,
      iconColor: AppColors.primary,
      currentValue: prefs.numberGrouping,
      options: [
        _SheetOption(
          value: AppNumberGrouping.southAsian,
          title: 'South Asian / Nepali',
          subtitle: 'Groups by hundreds, thousands, lakhs, and crores',
          example: '12,34,56,789.00',
        ),
        _SheetOption(
          value: AppNumberGrouping.international,
          title: 'International Standard',
          subtitle: 'Groups by thousands, millions, and billions',
          example: '123,456,789.00',
        ),
      ],
      onSelected: (val) => notifier.setNumberGrouping(val),
    );
  }

  void _showCurrencyPositionSheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
    AppCurrency currency,
  ) {
    _showSelectorBottomSheet<AppCurrencyPosition>(
      context: context,
      title: 'Currency Symbol Placement',
      subtitle: 'Choose whether symbol appears before or after the number',
      icon: Icons.currency_exchange_rounded,
      iconColor: const Color(0xFF10B981),
      currentValue: prefs.currencyPosition,
      options: [
        _SheetOption(
          value: AppCurrencyPosition.prefix,
          title: 'Before Amount (Prefix)',
          subtitle: 'Standard in Nepal, US, UK, and most currencies',
          example: '${currency.symbol} 1,234.56',
        ),
        _SheetOption(
          value: AppCurrencyPosition.suffix,
          title: 'After Amount (Suffix)',
          subtitle: 'Common in European and Scandinavian formats',
          example: '1,234.56 ${currency.symbol}',
        ),
      ],
      onSelected: (val) => notifier.setCurrencyPosition(val),
    );
  }

  void _showDecimalModeSheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
  ) {
    _showSelectorBottomSheet<AppDecimalMode>(
      context: context,
      title: 'Decimal Display',
      subtitle: 'Choose how fractional cents or paisa are shown',
      icon: Icons.straighten_rounded,
      iconColor: const Color(0xFFF59E0B),
      currentValue: prefs.decimalMode,
      options: const [
        _SheetOption(
          value: AppDecimalMode.alwaysTwo,
          title: 'Always Show Decimals',
          subtitle: 'Always displays 2 decimal places (e.g. .00)',
          example: '1,000.00',
        ),
        _SheetOption(
          value: AppDecimalMode.hideIfZero,
          title: 'Hide if Whole Number',
          subtitle: 'Shows whole amounts cleanly; shows decimals only if not .00',
          example: '1,000  (1,000.50)',
        ),
        _SheetOption(
          value: AppDecimalMode.integersOnly,
          title: 'Integers Only (Rounded)',
          subtitle: 'Always rounds amounts to the nearest whole integer',
          example: '1,000',
        ),
      ],
      onSelected: (val) => notifier.setDecimalMode(val),
    );
  }

  void _showDateFormatSheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
    DateTime now,
  ) {
    _showSelectorBottomSheet<AppDateFormat>(
      context: context,
      title: 'Date Display Format',
      subtitle: 'Choose how dates are shown across transactions and charts',
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF6366F1),
      currentValue: prefs.dateFormat,
      options: AppDateFormat.values.map((f) {
        return _SheetOption(
          value: f,
          title: f.label,
          subtitle: f == AppDateFormat.dmySlash
              ? 'Day First (Standard in Nepal, UK, India)'
              : f == AppDateFormat.mdySlash
                  ? 'Month First (Standard in US)'
                  : f == AppDateFormat.iso
                      ? 'ISO-8601 Standard'
                      : 'Text representation',
          example: AppDateFormatter.formatDate(now, format: f),
        );
      }).toList(),
      onSelected: (val) => notifier.setDateFormat(val),
    );
  }

  void _showTimeFormatSheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
    DateTime now,
  ) {
    _showSelectorBottomSheet<AppTimeFormat>(
      context: context,
      title: 'Time Display Format',
      subtitle: 'Choose between 12-hour AM/PM and 24-hour military clock',
      icon: Icons.access_time_rounded,
      iconColor: const Color(0xFF8B5CF6),
      currentValue: prefs.timeFormat,
      options: [
        _SheetOption(
          value: AppTimeFormat.twelveHour,
          title: '12-Hour (AM/PM)',
          subtitle: 'Standard 12-hour clock with AM/PM indicator',
          example: AppDateFormatter.formatTime(now, format: AppTimeFormat.twelveHour),
        ),
        _SheetOption(
          value: AppTimeFormat.twentyFourHour,
          title: '24-Hour',
          subtitle: '24-hour military clock without AM/PM',
          example: AppDateFormatter.formatTime(now, format: AppTimeFormat.twentyFourHour),
        ),
      ],
      onSelected: (val) => notifier.setTimeFormat(val),
    );
  }

  void _showFirstDaySheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
  ) {
    _showSelectorBottomSheet<int>(
      context: context,
      title: 'First Day of Week',
      subtitle: 'Starting day for calendar pickers and week calculations',
      icon: Icons.today_rounded,
      iconColor: const Color(0xFF06B6D4),
      currentValue: prefs.firstDayOfWeek,
      options: const [
        _SheetOption(
          value: DateTime.sunday,
          title: 'Sunday',
          subtitle: 'Standard in Nepal, US, Japan, Canada',
          example: 'Sun – Sat',
        ),
        _SheetOption(
          value: DateTime.monday,
          title: 'Monday',
          subtitle: 'ISO-8601 standard in Europe, UK, Australia',
          example: 'Mon – Sun',
        ),
      ],
      onSelected: (val) => notifier.setFirstDayOfWeek(val),
    );
  }

  void _showOcrDateStrategySheet(
    BuildContext context,
    AppPreferencesState prefs,
    AppPreferencesNotifier notifier,
  ) {
    _showSelectorBottomSheet<OcrDateFormatStrategy>(
      context: context,
      title: 'Ambiguous OCR Date Parsing',
      subtitle: 'How to resolve dates like 10/02/2026 when scanning receipts',
      icon: Icons.find_in_page_outlined,
      iconColor: const Color(0xFFEC4899),
      currentValue: prefs.ocrDateFormat,
      options: const [
        _SheetOption(
          value: OcrDateFormatStrategy.smartProximity,
          title: 'Smart Proximity',
          badge: 'Recommended',
          subtitle: 'Intelligently picks date closest to current date (avoids Feb 10 vs Oct 2 mixups)',
          example: 'Auto-smart',
        ),
        _SheetOption(
          value: OcrDateFormatStrategy.followApp,
          title: 'Follow App Date Format',
          subtitle: 'Strictly interprets receipt dates using your active App Date Format above',
          example: 'App Format',
        ),
        _SheetOption(
          value: OcrDateFormatStrategy.dmy,
          title: 'Day First (DD/MM)',
          subtitle: 'Always assumes first number is day of month (e.g. 10/02 → 10 Feb)',
          example: 'DD/MM',
        ),
        _SheetOption(
          value: OcrDateFormatStrategy.mdy,
          title: 'Month First (MM/DD)',
          subtitle: 'Always assumes first number is month of year (e.g. 10/02 → 02 Oct)',
          example: 'MM/DD',
        ),
      ],
      onSelected: (val) => notifier.setOcrDateFormat(val),
    );
  }

  void _showSelectorBottomSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required T currentValue,
    required List<_SheetOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.map((opt) {
                        final isSelected = opt.value == currentValue;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              onSelected(opt.value);
                              Navigator.pop(modalContext);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
                                    : (isDark
                                        ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5)
                                        : AppColors.lightSurfaceVariant.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? AppColors.primary : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                opt.title,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: isSelected
                                                      ? (isDark ? Colors.white : AppColors.primary)
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (opt.badge != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  opt.badge!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (opt.subtitle != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            opt.subtitle!,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (opt.example != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2235) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        ),
                                      ),
                                      child: Text(
                                        opt.example!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final String? example;
  final String? badge;

  const _SheetOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.example,
    this.badge,
  });
}
