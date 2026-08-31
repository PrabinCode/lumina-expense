import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/backup/services/import_wizard_service.dart';

void main() {
  group('ImportWizardService Tests', () {
    late AppDatabase db;
    late ImportWizardService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = ImportWizardService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('autoDetectMapping detects standard bank and app headers', () {
      final headers = ['Date', 'Payee / Description', 'Amount', 'Category', 'Account', 'Notes'];
      final mapping = service.autoDetectMapping(headers);

      expect(mapping.dateIndex, equals(0));
      expect(mapping.titleIndex, equals(1));
      expect(mapping.amountIndex, equals(2));
      expect(mapping.categoryIndex, equals(3));
      expect(mapping.accountIndex, equals(4));
      expect(mapping.noteIndex, equals(5));
      expect(mapping.isValid, isTrue);
    });

    test('generatePreview parses expense and income correctly', () {
      final headers = ['Date', 'Description', 'Amount', 'Category'];
      final rows = [
        ['2026-08-25', 'Starbucks Coffee', '4.50', 'Dining'],
        ['2026-08-26', 'Salary Paycheck', '+3500.00', 'Income'],
      ];

      final mapping = CsvColumnMapping(
        dateIndex: 0,
        titleIndex: 1,
        amountIndex: 2,
        categoryIndex: 3,
      );

      final preview = service.generatePreview(
        headers: headers,
        rows: rows,
        mapping: mapping,
      );

      expect(preview.totalRows, equals(2));
      expect(preview.totalExpense, equals(4.50));
      expect(preview.totalIncome, equals(3500.00));
      expect(preview.detectedCategories, containsAll(['Dining', 'Income']));
      expect(preview.parsedItems[0].title, equals('Starbucks Coffee'));
      expect(preview.parsedItems[0].type, equals('expense'));
      expect(preview.parsedItems[1].type, equals('income'));
    });
  });
}
