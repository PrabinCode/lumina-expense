import '../providers/app_preferences_provider.dart';

class CurrencyFormatter {
  /// Global active currency symbol set dynamically by CurrencyNotifier
  static String activeCurrencySymbol = '\$';

  /// Active formatting preferences
  static AppNumberGrouping activeGrouping = AppNumberGrouping.southAsian;
  static AppCurrencyPosition activePosition = AppCurrencyPosition.prefix;
  static AppDecimalMode activeDecimalMode = AppDecimalMode.alwaysTwo;

  /// Formats amount according to active currency symbol and formatting preferences
  static String format(
    double amount, {
    String? currencySymbol,
    bool mask = false,
    AppNumberGrouping? grouping,
    AppCurrencyPosition? position,
    AppDecimalMode? decimalMode,
  }) {
    final symbol = currencySymbol ?? activeCurrencySymbol;
    final pos = position ?? activePosition;

    if (mask) {
      return pos == AppCurrencyPosition.prefix ? '$symbol••••' : '•••• $symbol';
    }

    final groupStyle = grouping ?? activeGrouping;
    final decMode = decimalMode ?? activeDecimalMode;

    final isNegative = amount < 0;
    final absAmount = amount.abs();

    String intPartStr;
    String decPartStr = '';

    if (decMode == AppDecimalMode.integersOnly) {
      intPartStr = absAmount.round().toString();
    } else {
      final fixed = absAmount.toStringAsFixed(2);
      final parts = fixed.split('.');
      intPartStr = parts[0];
      final cents = parts[1];

      if (decMode == AppDecimalMode.alwaysTwo) {
        decPartStr = '.$cents';
      } else if (decMode == AppDecimalMode.hideIfZero) {
        if (cents != '00') {
          decPartStr = '.$cents';
        }
      }
    }

    final formattedInt = groupStyle == AppNumberGrouping.southAsian
        ? _formatSouthAsian(intPartStr)
        : _formatInternational(intPartStr);

    var formattedNumber = '$formattedInt$decPartStr';
    if (isNegative) {
      formattedNumber = '-$formattedNumber';
    }

    if (pos == AppCurrencyPosition.prefix) {
      final needSpace = symbol.length > 1 && !symbol.endsWith(' ');
      return needSpace ? '$symbol $formattedNumber' : '$symbol$formattedNumber';
    } else {
      final needSpace = !symbol.startsWith(' ');
      return needSpace ? '$formattedNumber $symbol' : '$formattedNumber$symbol';
    }
  }

  static String _formatSouthAsian(String intPart) {
    if (intPart.length <= 3) return intPart;
    final last3 = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      buffer.write(remaining[i]);
      final charsFromEnd = remaining.length - 1 - i;
      if (charsFromEnd > 0 && charsFromEnd % 2 == 0) {
        buffer.write(',');
      }
    }
    buffer.write(',');
    buffer.write(last3);
    return buffer.toString();
  }

  static String _formatInternational(String intPart) {
    if (intPart.length <= 3) return intPart;
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      buffer.write(intPart[i]);
      final charsFromEnd = intPart.length - 1 - i;
      if (charsFromEnd > 0 && charsFromEnd % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static String formatCompact(
    double amount, {
    String? currencySymbol,
    bool mask = false,
    AppNumberGrouping? grouping,
    AppCurrencyPosition? position,
  }) {
    final symbol = currencySymbol ?? activeCurrencySymbol;
    final pos = position ?? activePosition;
    final groupStyle = grouping ?? activeGrouping;

    if (mask) {
      return pos == AppCurrencyPosition.prefix ? '$symbol••••' : '•••• $symbol';
    }

    final absVal = amount.abs();
    final isNegative = amount < 0;

    String formattedCompact;
    if (groupStyle == AppNumberGrouping.southAsian) {
      // South Asian compact units (Karod / Lakh / k)
      if (absVal >= 10000000) {
        formattedCompact = '${(absVal / 10000000).toStringAsFixed(1)}Cr';
      } else if (absVal >= 100000) {
        formattedCompact = '${(absVal / 100000).toStringAsFixed(1)}L';
      } else if (absVal >= 1000) {
        formattedCompact = '${(absVal / 1000).toStringAsFixed(1)}k';
      } else {
        return format(amount, currencySymbol: symbol, grouping: groupStyle, position: pos);
      }
    } else {
      // International compact units (Billion / Million / k)
      if (absVal >= 1000000000) {
        formattedCompact = '${(absVal / 1000000000).toStringAsFixed(1)}B';
      } else if (absVal >= 1000000) {
        formattedCompact = '${(absVal / 1000000).toStringAsFixed(1)}M';
      } else if (absVal >= 1000) {
        formattedCompact = '${(absVal / 1000).toStringAsFixed(1)}k';
      } else {
        return format(amount, currencySymbol: symbol, grouping: groupStyle, position: pos);
      }
    }

    if (isNegative) {
      formattedCompact = '-$formattedCompact';
    }

    if (pos == AppCurrencyPosition.prefix) {
      final needSpace = symbol.length > 1;
      return needSpace ? '$symbol $formattedCompact' : '$symbol$formattedCompact';
    } else {
      return '$formattedCompact $symbol';
    }
  }

  static String compact(double amount, {String? currencySymbol, bool mask = false}) =>
      formatCompact(amount, currencySymbol: currencySymbol, mask: mask);
}
