import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/currency_formatter.dart';

/// Representation of a supported world currency
class AppCurrency {
  final String code; // e.g. USD, NPR, EUR
  final String symbol; // e.g. $, Rs., €
  final String name; // e.g. US Dollar, Nepalese Rupee
  final String country; // e.g. United States, Nepal
  final String flag; // e.g. 🇺🇸, 🇳🇵

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.country,
    required this.flag,
  });

  String get displayName => '$flag $code - $name ($symbol)';
}

/// Comprehensive list of popular world currencies
const List<AppCurrency> supportedCurrencies = [
  AppCurrency(code: 'USD', symbol: '\$', name: 'US Dollar', country: 'United States', flag: '🇺🇸'),
  AppCurrency(code: 'NPR', symbol: 'Rs.', name: 'Nepalese Rupee', country: 'Nepal', flag: '🇳🇵'),
  AppCurrency(code: 'INR', symbol: '₹', name: 'Indian Rupee', country: 'India', flag: '🇮🇳'),
  AppCurrency(code: 'EUR', symbol: '€', name: 'Euro', country: 'European Union', flag: '🇪🇺'),
  AppCurrency(code: 'GBP', symbol: '£', name: 'British Pound', country: 'United Kingdom', flag: '🇬🇧'),
  AppCurrency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', country: 'Japan', flag: '🇯🇵'),
  AppCurrency(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar', country: 'Canada', flag: '🇨🇦'),
  AppCurrency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', country: 'Australia', flag: '🇦🇺'),
  AppCurrency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', country: 'China', flag: '🇨🇳'),
  AppCurrency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', country: 'Singapore', flag: '🇸🇬'),
  AppCurrency(code: 'AED', symbol: 'AED', name: 'UAE Dirham', country: 'United Arab Emirates', flag: '🇦🇪'),
  AppCurrency(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal', country: 'Saudi Arabia', flag: '🇸🇦'),
  AppCurrency(code: 'QAR', symbol: 'QAR', name: 'Qatari Riyal', country: 'Qatar', flag: '🇶🇦'),
  AppCurrency(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', country: 'Malaysia', flag: '🇲🇾'),
  AppCurrency(code: 'THB', symbol: '฿', name: 'Thai Baht', country: 'Thailand', flag: '🇹🇭'),
  AppCurrency(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka', country: 'Bangladesh', flag: '🇧🇩'),
  AppCurrency(code: 'PKR', symbol: 'PKR', name: 'Pakistani Rupee', country: 'Pakistan', flag: '🇵🇰'),
  AppCurrency(code: 'LKR', symbol: 'Rs', name: 'Sri Lankan Rupee', country: 'Sri Lanka', flag: '🇱🇰'),
  AppCurrency(code: 'PHP', symbol: '₱', name: 'Philippine Peso', country: 'Philippines', flag: '🇵🇭'),
  AppCurrency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', country: 'Indonesia', flag: '🇮🇩'),
  AppCurrency(code: 'VND', symbol: '₫', name: 'Vietnamese Dong', country: 'Vietnam', flag: '🇻🇳'),
  AppCurrency(code: 'KRW', symbol: '₩', name: 'South Korean Won', country: 'South Korea', flag: '🇰🇷'),
  AppCurrency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', country: 'Brazil', flag: '🇧🇷'),
  AppCurrency(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso', country: 'Mexico', flag: '🇲🇽'),
  AppCurrency(code: 'ZAR', symbol: 'R', name: 'South African Rand', country: 'South Africa', flag: '🇿🇦'),
  AppCurrency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', country: 'Switzerland', flag: '🇨🇭'),
  AppCurrency(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', country: 'New Zealand', flag: '🇳🇿'),
  AppCurrency(code: 'TRY', symbol: '₺', name: 'Turkish Lira', country: 'Turkey', flag: '🇹🇷'),
  AppCurrency(code: 'RUB', symbol: '₽', name: 'Russian Ruble', country: 'Russia', flag: '🇷🇺'),
  AppCurrency(code: 'NGN', symbol: '₦', name: 'Nigerian Naira', country: 'Nigeria', flag: '🇳🇬'),
  AppCurrency(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', country: 'Kenya', flag: '🇰🇪'),
  AppCurrency(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound', country: 'Egypt', flag: '🇪🇬'),
];

/// Notifier managing global active currency with SharedPreferences persistence
class CurrencyNotifier extends StateNotifier<AppCurrency> {
  static const _keyCurrencyCode = 'selected_currency_code';

  CurrencyNotifier() : super(supportedCurrencies.first) {
    _loadPersistedCurrency();
  }

  Future<void> _loadPersistedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_keyCurrencyCode);
      if (savedCode != null) {
        final match = supportedCurrencies.firstWhere(
          (c) => c.code == savedCode,
          orElse: () => supportedCurrencies.first,
        );
        state = match;
        CurrencyFormatter.activeCurrencySymbol = match.symbol;
      } else {
        CurrencyFormatter.activeCurrencySymbol = state.symbol;
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }

  Future<void> setCurrency(AppCurrency currency) async {
    state = currency;
    CurrencyFormatter.activeCurrencySymbol = currency.symbol;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrencyCode, currency.code);
    } catch (e) {
      debugPrint('Error saving currency: $e');
    }
  }
}

/// Global active currency provider
final currencyProvider = StateNotifierProvider<CurrencyNotifier, AppCurrency>((ref) {
  return CurrencyNotifier();
});
