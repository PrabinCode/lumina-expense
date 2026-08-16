import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currencySymbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currencySymbol = '\$'}) {
    if (amount.abs() >= 1000000) {
      return '$currencySymbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '$currencySymbol${(amount / 1000).toStringAsFixed(1)}k';
    }
    return format(amount, currencySymbol: currencySymbol);
  }
}
