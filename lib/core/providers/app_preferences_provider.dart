import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/currency_formatter.dart';
import '../utils/app_date_formatter.dart';

enum AppDateFormat {
  dmySlash('dd/MM/yyyy', 'DD/MM/YYYY', '02/10/2026'),
  mdySlash('MM/dd/yyyy', 'MM/DD/YYYY', '10/02/2026'),
  iso('yyyy-MM-dd', 'YYYY-MM-DD', '2026-10-02'),
  dmyText('dd MMM yyyy', 'DD MMM YYYY', '02 Oct 2026'),
  mdyText('MMM dd, yyyy', 'MMM DD, YYYY', 'Oct 02, 2026');

  final String pattern;
  final String label;
  final String example;

  const AppDateFormat(this.pattern, this.label, this.example);
}

enum AppTimeFormat {
  twelveHour('12-Hour (AM/PM)', '08:30 PM', 'hh:mm a'),
  twentyFourHour('24-Hour', '20:30', 'HH:mm');

  final String label;
  final String example;
  final String pattern;

  const AppTimeFormat(this.label, this.example, this.pattern);
}

enum AppNumberGrouping {
  international('International (123,456,789)', '123,456,789.00'),
  southAsian('South Asian / Nepali (12,34,56,789)', '12,34,56,789.00');

  final String label;
  final String example;

  const AppNumberGrouping(this.label, this.example);
}

enum AppCurrencyPosition {
  prefix('Before Amount (e.g. Rs. 1,000 / \$1,000)'),
  suffix('After Amount (e.g. 1,000 Rs. / 1,000 \$)');

  final String label;

  const AppCurrencyPosition(this.label);
}

enum AppDecimalMode {
  alwaysTwo('Always 2 Decimals', '1,000.00'),
  hideIfZero('Hide if .00', '1,000 (or 1,000.50)'),
  integersOnly('Integers Only (Rounded)', '1,000');

  final String label;
  final String example;

  const AppDecimalMode(this.label, this.example);
}

enum OcrDateFormatStrategy {
  smartProximity('Smart Proximity (Recommended)', 'Picks the date closest to today when ambiguous (e.g. Oct 2 vs Feb 10)'),
  followApp('Follow App Date Format', 'Uses the app\'s chosen date display format to resolve ambiguous dates'),
  dmy('Day / Month / Year (DD/MM/YYYY)', 'Always assumes day comes first when ambiguous'),
  mdy('Month / Day / Year (MM/DD/YYYY)', 'Always assumes month comes first when ambiguous');

  final String label;
  final String description;

  const OcrDateFormatStrategy(this.label, this.description);
}

class AppPreferencesState {
  final AppDateFormat dateFormat;
  final AppTimeFormat timeFormat;
  final int firstDayOfWeek; // DateTime.sunday (7) or DateTime.monday (1)
  final AppNumberGrouping numberGrouping;
  final AppCurrencyPosition currencyPosition;
  final AppDecimalMode decimalMode;
  final OcrDateFormatStrategy ocrDateFormat;
  final bool ocrScanNotes;
  final bool ocrAutoCategory;

  const AppPreferencesState({
    required this.dateFormat,
    required this.timeFormat,
    required this.firstDayOfWeek,
    required this.numberGrouping,
    required this.currencyPosition,
    required this.decimalMode,
    required this.ocrDateFormat,
    required this.ocrScanNotes,
    required this.ocrAutoCategory,
  });

  AppPreferencesState copyWith({
    AppDateFormat? dateFormat,
    AppTimeFormat? timeFormat,
    int? firstDayOfWeek,
    AppNumberGrouping? numberGrouping,
    AppCurrencyPosition? currencyPosition,
    AppDecimalMode? decimalMode,
    OcrDateFormatStrategy? ocrDateFormat,
    bool? ocrScanNotes,
    bool? ocrAutoCategory,
  }) {
    return AppPreferencesState(
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      numberGrouping: numberGrouping ?? this.numberGrouping,
      currencyPosition: currencyPosition ?? this.currencyPosition,
      decimalMode: decimalMode ?? this.decimalMode,
      ocrDateFormat: ocrDateFormat ?? this.ocrDateFormat,
      ocrScanNotes: ocrScanNotes ?? this.ocrScanNotes,
      ocrAutoCategory: ocrAutoCategory ?? this.ocrAutoCategory,
    );
  }
}

class AppPreferencesNotifier extends StateNotifier<AppPreferencesState> {
  static const _keyDateFormat = 'pref_date_format';
  static const _keyTimeFormat = 'pref_time_format';
  static const _keyFirstDayOfWeek = 'pref_first_day_of_week';
  static const _keyNumberGrouping = 'pref_number_grouping';
  static const _keyCurrencyPosition = 'pref_currency_position';
  static const _keyDecimalMode = 'pref_decimal_mode';
  static const _keyOcrDateFormat = 'pref_ocr_date_format';
  static const _keyOcrScanNotes = 'pref_ocr_scan_notes';
  static const _keyOcrAutoCategory = 'pref_ocr_auto_category';

  AppPreferencesNotifier()
      : super(const AppPreferencesState(
          dateFormat: AppDateFormat.dmySlash,
          timeFormat: AppTimeFormat.twelveHour,
          firstDayOfWeek: DateTime.sunday,
          numberGrouping: AppNumberGrouping.southAsian,
          currencyPosition: AppCurrencyPosition.prefix,
          decimalMode: AppDecimalMode.alwaysTwo,
          ocrDateFormat: OcrDateFormatStrategy.smartProximity,
          ocrScanNotes: true,
          ocrAutoCategory: true,
        )) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCurrencyCode = prefs.getString('selected_currency_code') ?? 'NPR';
      final isSouthAsianDefault = savedCurrencyCode == 'NPR' || savedCurrencyCode == 'INR';

      // Date Format
      final savedDateFormat = prefs.getString(_keyDateFormat);
      final dateFormat = savedDateFormat != null
          ? AppDateFormat.values.firstWhere(
              (e) => e.name == savedDateFormat,
              orElse: () => isSouthAsianDefault ? AppDateFormat.dmySlash : AppDateFormat.mdySlash,
            )
          : (isSouthAsianDefault ? AppDateFormat.dmySlash : AppDateFormat.mdySlash);

      // Time Format
      final savedTimeFormat = prefs.getString(_keyTimeFormat);
      final timeFormat = savedTimeFormat != null
          ? AppTimeFormat.values.firstWhere(
              (e) => e.name == savedTimeFormat,
              orElse: () => AppTimeFormat.twelveHour,
            )
          : AppTimeFormat.twelveHour;

      // First Day of Week
      final firstDayOfWeek = prefs.getInt(_keyFirstDayOfWeek) ?? DateTime.sunday;

      // Number Grouping
      final savedNumberGrouping = prefs.getString(_keyNumberGrouping);
      final numberGrouping = savedNumberGrouping != null
          ? AppNumberGrouping.values.firstWhere(
              (e) => e.name == savedNumberGrouping,
              orElse: () => isSouthAsianDefault ? AppNumberGrouping.southAsian : AppNumberGrouping.international,
            )
          : (isSouthAsianDefault ? AppNumberGrouping.southAsian : AppNumberGrouping.international);

      // Currency Position
      final savedCurrencyPos = prefs.getString(_keyCurrencyPosition);
      final currencyPosition = savedCurrencyPos != null
          ? AppCurrencyPosition.values.firstWhere(
              (e) => e.name == savedCurrencyPos,
              orElse: () => AppCurrencyPosition.prefix,
            )
          : AppCurrencyPosition.prefix;

      // Decimal Mode
      final savedDecimalMode = prefs.getString(_keyDecimalMode);
      final decimalMode = savedDecimalMode != null
          ? AppDecimalMode.values.firstWhere(
              (e) => e.name == savedDecimalMode,
              orElse: () => AppDecimalMode.alwaysTwo,
            )
          : AppDecimalMode.alwaysTwo;

      // OCR Date Format
      final savedOcrDateFormat = prefs.getString(_keyOcrDateFormat);
      final ocrDateFormat = savedOcrDateFormat != null
          ? OcrDateFormatStrategy.values.firstWhere(
              (e) => e.name == savedOcrDateFormat,
              orElse: () => OcrDateFormatStrategy.smartProximity,
            )
          : OcrDateFormatStrategy.smartProximity;

      // OCR Scan Notes
      final ocrScanNotes = prefs.getBool(_keyOcrScanNotes) ?? true;

      // OCR Auto Category
      final ocrAutoCategory = prefs.getBool(_keyOcrAutoCategory) ?? true;

      state = AppPreferencesState(
        dateFormat: dateFormat,
        timeFormat: timeFormat,
        firstDayOfWeek: firstDayOfWeek,
        numberGrouping: numberGrouping,
        currencyPosition: currencyPosition,
        decimalMode: decimalMode,
        ocrDateFormat: ocrDateFormat,
        ocrScanNotes: ocrScanNotes,
        ocrAutoCategory: ocrAutoCategory,
      );

      _syncWithFormatters(state);
    } catch (e) {
      debugPrint('Error loading app preferences: $e');
    }
  }

  void _syncWithFormatters(AppPreferencesState state) {
    CurrencyFormatter.activeGrouping = state.numberGrouping;
    CurrencyFormatter.activePosition = state.currencyPosition;
    CurrencyFormatter.activeDecimalMode = state.decimalMode;

    AppDateFormatter.activeDateFormat = state.dateFormat;
    AppDateFormatter.activeTimeFormat = state.timeFormat;
  }

  Future<void> setDateFormat(AppDateFormat format) async {
    state = state.copyWith(dateFormat: format);
    _syncWithFormatters(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDateFormat, format.name);
  }

  Future<void> setTimeFormat(AppTimeFormat format) async {
    state = state.copyWith(timeFormat: format);
    _syncWithFormatters(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimeFormat, format.name);
  }

  Future<void> setFirstDayOfWeek(int firstDay) async {
    state = state.copyWith(firstDayOfWeek: firstDay);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFirstDayOfWeek, firstDay);
  }

  Future<void> setNumberGrouping(AppNumberGrouping grouping) async {
    state = state.copyWith(numberGrouping: grouping);
    _syncWithFormatters(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumberGrouping, grouping.name);
  }

  Future<void> setCurrencyPosition(AppCurrencyPosition position) async {
    state = state.copyWith(currencyPosition: position);
    _syncWithFormatters(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrencyPosition, position.name);
  }

  Future<void> setDecimalMode(AppDecimalMode mode) async {
    state = state.copyWith(decimalMode: mode);
    _syncWithFormatters(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDecimalMode, mode.name);
  }

  Future<void> setOcrDateFormat(OcrDateFormatStrategy strategy) async {
    state = state.copyWith(ocrDateFormat: strategy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOcrDateFormat, strategy.name);
  }

  Future<void> setOcrScanNotes(bool value) async {
    state = state.copyWith(ocrScanNotes: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOcrScanNotes, value);
  }

  Future<void> setOcrAutoCategory(bool value) async {
    state = state.copyWith(ocrAutoCategory: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOcrAutoCategory, value);
  }
}

final appPreferencesProvider = StateNotifierProvider<AppPreferencesNotifier, AppPreferencesState>((ref) {
  return AppPreferencesNotifier();
});
