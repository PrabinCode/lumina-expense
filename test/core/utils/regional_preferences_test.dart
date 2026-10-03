import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/providers/app_preferences_provider.dart';
import 'package:lumina_expense/core/services/receipt_parser_service.dart';
import 'package:lumina_expense/core/utils/app_date_formatter.dart';
import 'package:lumina_expense/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter - Number Grouping & Currency Positioning', () {
    test('formats South Asian (Nepali / Indian) Lakhs and Crores grouping', () {
      expect(
        CurrencyFormatter.format(
          123456789.00,
          currencySymbol: 'Rs.',
          grouping: AppNumberGrouping.southAsian,
          position: AppCurrencyPosition.prefix,
        ),
        equals('Rs. 12,34,56,789.00'),
      );

      expect(
        CurrencyFormatter.format(
          4116.00,
          currencySymbol: 'Rs.',
          grouping: AppNumberGrouping.southAsian,
          position: AppCurrencyPosition.prefix,
        ),
        equals('Rs. 4,116.00'),
      );

      expect(
        CurrencyFormatter.format(
          55669666666.00,
          currencySymbol: '\$',
          grouping: AppNumberGrouping.southAsian,
          position: AppCurrencyPosition.prefix,
        ),
        equals('\$55,66,96,66,666.00'),
      );
    });

    test('formats International (US / Western) thousands grouping', () {
      expect(
        CurrencyFormatter.format(
          123456789.00,
          currencySymbol: '\$',
          grouping: AppNumberGrouping.international,
          position: AppCurrencyPosition.prefix,
        ),
        equals('\$123,456,789.00'),
      );

      expect(
        CurrencyFormatter.format(
          55669666666.00,
          currencySymbol: '\$',
          grouping: AppNumberGrouping.international,
          position: AppCurrencyPosition.prefix,
        ),
        equals('\$55,669,666,666.00'),
      );
    });

    test('supports currency symbol suffix placement', () {
      expect(
        CurrencyFormatter.format(
          1500.50,
          currencySymbol: 'NPR',
          grouping: AppNumberGrouping.southAsian,
          position: AppCurrencyPosition.suffix,
        ),
        equals('1,500.50 NPR'),
      );
    });

    test('supports decimal display modes (alwaysTwo, hideIfZero, integersOnly)', () {
      // alwaysTwo
      expect(
        CurrencyFormatter.format(
          1000.0,
          currencySymbol: 'Rs.',
          decimalMode: AppDecimalMode.alwaysTwo,
        ),
        equals('Rs. 1,000.00'),
      );

      // hideIfZero
      expect(
        CurrencyFormatter.format(
          1000.0,
          currencySymbol: 'Rs.',
          decimalMode: AppDecimalMode.hideIfZero,
        ),
        equals('Rs. 1,000'),
      );
      expect(
        CurrencyFormatter.format(
          1000.75,
          currencySymbol: 'Rs.',
          decimalMode: AppDecimalMode.hideIfZero,
        ),
        equals('Rs. 1,000.75'),
      );

      // integersOnly
      expect(
        CurrencyFormatter.format(
          1000.85,
          currencySymbol: 'Rs.',
          decimalMode: AppDecimalMode.integersOnly,
        ),
        equals('Rs. 1,001'),
      );
    });

    test('compact formatting adapts to grouping system', () {
      // South Asian: Lakhs and Crores
      expect(
        CurrencyFormatter.formatCompact(
          55669666666.0,
          currencySymbol: 'Rs.',
          grouping: AppNumberGrouping.southAsian,
        ),
        equals('Rs. 5567.0Cr'),
      );

      // International: Billions and Millions
      expect(
        CurrencyFormatter.formatCompact(
          55669666666.0,
          currencySymbol: '\$',
          grouping: AppNumberGrouping.international,
        ),
        equals('\$55.7B'),
      );
    });
  });

  group('ReceiptParserService - Ambiguous Date Disambiguation & Proximity', () {
    late ReceiptParserService parser;

    setUp(() {
      parser = ReceiptParserService();
    });

    const userReceipt = '''
      D.G. Prisha Pvt. Ltd.
      Budhanilkantha
      PAN No. : 623556146
      ABBREVIATED TAX INVOICE

      Bill NO: SI19275-DGP-83/84
      Date : 10/02/2026
      Miti : 16/06/2083
      Name :
      Payment Mode : FonePay

      1  Nepali Rajma Open    1  240  240
      2  TARAI TICHIN CHIUR   2   83  166
      3  MAAS KAALO DAAL OP   1  195  195

      Gross Amount: 4116.00
      Net Amount  : 4116.00
      Tender      : 4116.00
      Total Qty   : 19.00
      Rs. Four thousand one hundred sixteen only
    ''';

    test('extracts October 2, 2026 with Smart Proximity on user receipt', () {
      final result = parser.parse(
        userReceipt,
        ocrDateStrategy: OcrDateFormatStrategy.smartProximity,
      );

      expect(result.amount, equals(4116.00));
      expect(result.merchantName, contains('Prisha'));
      // Date must be October 2, 2026 (yesterday) rather than Feb 10, 2026!
      expect(result.date, equals(DateTime(2026, 10, 2)));
      expect(result.particulars, isNotEmpty);
      expect(result.particulars.first, contains('Nepali Rajma'));
    });

    test('extracts October 2, 2026 when strategy is Month/Day (MDY)', () {
      final result = parser.parse(
        userReceipt,
        ocrDateStrategy: OcrDateFormatStrategy.mdy,
      );

      expect(result.date, equals(DateTime(2026, 10, 2)));
    });

    test('extracts February 10, 2026 when strategy is explicitly Day/Month (DMY)', () {
      final result = parser.parse(
        userReceipt,
        ocrDateStrategy: OcrDateFormatStrategy.dmy,
      );

      expect(result.date, equals(DateTime(2026, 2, 10)));
    });

    test('follows app date format when strategy is followApp', () {
      final resultMdy = parser.parse(
        userReceipt,
        ocrDateStrategy: OcrDateFormatStrategy.followApp,
        appDateFormat: AppDateFormat.mdySlash,
      );
      expect(resultMdy.date, equals(DateTime(2026, 10, 2)));

      final resultDmy = parser.parse(
        userReceipt,
        ocrDateStrategy: OcrDateFormatStrategy.followApp,
        appDateFormat: AppDateFormat.dmySlash,
      );
      expect(resultDmy.date, equals(DateTime(2026, 2, 10)));
    });
  });

  group('AppDateFormatter - Formatting Rules', () {
    final testDate = DateTime(2026, 10, 2, 20, 30); // Oct 2, 2026 8:30 PM

    test('formats dates according to AppDateFormat options', () {
      expect(AppDateFormatter.formatDate(testDate, format: AppDateFormat.dmySlash), equals('02/10/2026'));
      expect(AppDateFormatter.formatDate(testDate, format: AppDateFormat.mdySlash), equals('10/02/2026'));
      expect(AppDateFormatter.formatDate(testDate, format: AppDateFormat.iso), equals('2026-10-02'));
      expect(AppDateFormatter.formatDate(testDate, format: AppDateFormat.dmyText), equals('02 Oct 2026'));
      expect(AppDateFormatter.formatDate(testDate, format: AppDateFormat.mdyText), equals('Oct 02, 2026'));
    });

    test('formats times according to AppTimeFormat options', () {
      expect(AppDateFormatter.formatTime(testDate, format: AppTimeFormat.twelveHour), equals('08:30 PM'));
      expect(AppDateFormatter.formatTime(testDate, format: AppTimeFormat.twentyFourHour), equals('20:30'));
    });

    test('formats combined date and time', () {
      expect(
        AppDateFormatter.formatDateTime(
          testDate,
          dateFormat: AppDateFormat.dmySlash,
          timeFormat: AppTimeFormat.twelveHour,
        ),
        equals('02/10/2026 • 08:30 PM'),
      );
    });
  });
}
