import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Global active currency symbol set dynamically by CurrencyNotifier
  static String activeCurrencySymbol = '\$';

  static String format(double amount, {String? currencySymbol}) {
    final symbol = currencySymbol ?? activeCurrencySymbol;
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String? currencySymbol}) {
    final symbol = currencySymbol ?? activeCurrencySymbol;
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}k';
    }
    return format(amount, currencySymbol: symbol);
  }
}
