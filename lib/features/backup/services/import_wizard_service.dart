import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class CsvColumnMapping {
  int dateIndex;
  int titleIndex;
  int amountIndex;
  int? categoryIndex;
  int? accountIndex;
  int? typeIndex; // expense / income
  int? debitIndex; // for bank statements with separate Debit column
  int? creditIndex; // for bank statements with separate Credit column
  int? noteIndex;

  CsvColumnMapping({
    this.dateIndex = -1,
    this.titleIndex = -1,
    this.amountIndex = -1,
    this.categoryIndex,
    this.accountIndex,
    this.typeIndex,
    this.debitIndex,
    this.creditIndex,
    this.noteIndex,
  });

  bool get isValid => dateIndex >= 0 && titleIndex >= 0 && (amountIndex >= 0 || (debitIndex != null && creditIndex != null));
}

class CsvParsedItem {
  final DateTime date;
  final String title;
  final double amount;
  final String type; // 'expense' or 'income'
  final String? categoryName;
  final String? accountName;
  final String? note;

  CsvParsedItem({
    required this.date,
    required this.title,
    required this.amount,
    required this.type,
    this.categoryName,
    this.accountName,
    this.note,
  });
}

class CsvImportPreview {
  final List<String> headers;
  final List<List<dynamic>> rawSampleRows;
  final List<CsvParsedItem> parsedItems;
  final int totalRows;
  final double totalIncome;
  final double totalExpense;
  final Set<String> detectedCategories;
  final Set<String> detectedAccounts;

  CsvImportPreview({
    required this.headers,
    required this.rawSampleRows,
    required this.parsedItems,
    required this.totalRows,
    required this.totalIncome,
    required this.totalExpense,
    required this.detectedCategories,
    required this.detectedAccounts,
  });
}

class ImportWizardService {
  final AppDatabase _db;

  ImportWizardService(this._db);

  /// Parse CSV raw lines and detect columns
  Future<({List<String> headers, List<List<dynamic>> rows})> parseRawCsv(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);

    if (rows.isEmpty) {
      throw const FormatException('Selected CSV file is empty.');
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    return (headers: headers, rows: dataRows);
  }

  /// Automatically guess mapping based on header column names
  CsvColumnMapping autoDetectMapping(List<String> headers) {
    final mapping = CsvColumnMapping();

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (mapping.dateIndex == -1 && (h.contains('date') || h.contains('time') || h == 'dt')) {
        mapping.dateIndex = i;
      } else if (mapping.titleIndex == -1 &&
          (h.contains('title') ||
              h.contains('description') ||
              h.contains('payee') ||
              h.contains('name') ||
              h.contains('item') ||
              h.contains('memo') ||
              h.contains('narrative'))) {
        mapping.titleIndex = i;
      } else if (mapping.amountIndex == -1 &&
          (h == 'amount' || h == 'val' || h == 'value' || h == 'total' || h == 'sum')) {
        mapping.amountIndex = i;
      } else if (h.contains('debit') || h.contains('outflow') || h.contains('withdrawal')) {
        mapping.debitIndex = i;
      } else if (h.contains('credit') || h.contains('inflow') || h.contains('deposit')) {
        mapping.creditIndex = i;
      } else if (mapping.categoryIndex == null && (h.contains('category') || h.contains('cat'))) {
        mapping.categoryIndex = i;
      } else if (mapping.accountIndex == null && (h.contains('account') || h.contains('wallet') || h.contains('bank'))) {
        mapping.accountIndex = i;
      } else if (mapping.typeIndex == null && (h.contains('type') || h == 'kind')) {
        mapping.typeIndex = i;
      } else if (mapping.noteIndex == null && (h.contains('note') || h.contains('comment') || h.contains('remark'))) {
        mapping.noteIndex = i;
      }
    }

    // Fallbacks if not detected
    if (mapping.dateIndex == -1 && headers.isNotEmpty) mapping.dateIndex = 0;
    if (mapping.titleIndex == -1 && headers.length > 1) mapping.titleIndex = 1;
    if (mapping.amountIndex == -1 && mapping.debitIndex == null && headers.length > 2) mapping.amountIndex = 2;

    return mapping;
  }

  /// Generate dry-run preview from mapped rows
  CsvImportPreview generatePreview({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required CsvColumnMapping mapping,
  }) {
    final parsedItems = <CsvParsedItem>[];
    double totalIncome = 0;
    double totalExpense = 0;
    final detectedCategories = <String>{};
    final detectedAccounts = <String>{};

    for (final row in rows) {
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

      try {
        final dateStr = mapping.dateIndex >= 0 && mapping.dateIndex < row.length ? row[mapping.dateIndex].toString().trim() : '';
        final title = mapping.titleIndex >= 0 && mapping.titleIndex < row.length ? row[mapping.titleIndex].toString().trim() : 'Transaction';
        final parsedDate = _parseDate(dateStr);

        double amount = 0;
        String type = 'expense';

        if (mapping.debitIndex != null && mapping.creditIndex != null) {
          final debitStr = mapping.debitIndex! < row.length ? row[mapping.debitIndex!].toString().trim() : '';
          final creditStr = mapping.creditIndex! < row.length ? row[mapping.creditIndex!].toString().trim() : '';
          final debit = _parseAmount(debitStr);
          final credit = _parseAmount(creditStr);

          if (credit > 0) {
            amount = credit;
            type = 'income';
          } else {
            amount = debit.abs();
            type = 'expense';
          }
        } else if (mapping.amountIndex >= 0 && mapping.amountIndex < row.length) {
          final amountStr = row[mapping.amountIndex].toString().trim();
          final rawAmount = _parseAmount(amountStr);

          if (mapping.typeIndex != null && mapping.typeIndex! < row.length) {
            final typeStr = row[mapping.typeIndex!].toString().toLowerCase().trim();
            type = (typeStr.contains('income') || typeStr.contains('deposit') || typeStr.contains('inflow'))
                ? 'income'
                : 'expense';
            amount = rawAmount.abs();
          } else {
            if (rawAmount < 0) {
              amount = rawAmount.abs();
              type = 'expense';
            } else if (amountStr.startsWith('+')) {
              amount = rawAmount;
              type = 'income';
            } else {
              amount = rawAmount;
              type = 'expense';
            }
          }
        }

        if (amount == 0 && title.isEmpty) continue;

        String? categoryName;
        if (mapping.categoryIndex != null && mapping.categoryIndex! < row.length) {
          final cat = row[mapping.categoryIndex!].toString().trim();
          if (cat.isNotEmpty) {
            categoryName = cat;
            detectedCategories.add(cat);
          }
        }

        String? accountName;
        if (mapping.accountIndex != null && mapping.accountIndex! < row.length) {
          final acc = row[mapping.accountIndex!].toString().trim();
          if (acc.isNotEmpty) {
            accountName = acc;
            detectedAccounts.add(acc);
          }
        }

        String? note;
        if (mapping.noteIndex != null && mapping.noteIndex! < row.length) {
          final n = row[mapping.noteIndex!].toString().trim();
          if (n.isNotEmpty) note = n;
        }

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }

        parsedItems.add(CsvParsedItem(
          date: parsedDate,
          title: title.isNotEmpty ? title : 'Imported Item',
          amount: amount,
          type: type,
          categoryName: categoryName,
          accountName: accountName,
          note: note,
        ));
      } catch (_) {}
    }

    return CsvImportPreview(
      headers: headers,
      rawSampleRows: rows.take(5).toList(),
      parsedItems: parsedItems,
      totalRows: parsedItems.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      detectedCategories: detectedCategories,
      detectedAccounts: detectedAccounts,
    );
  }

  /// Execute import into database
  Future<int> executeImport({
    required List<CsvParsedItem> items,
    required String defaultAccountId,
    String? defaultCategoryId,
    bool autoCreateCategories = true,
  }) async {
    final existingCategories = await _db.select(_db.categories).get();
    final categoryMap = <String, String>{
      for (final c in existingCategories) c.name.toLowerCase(): c.id,
    };

    final existingAccounts = await _db.select(_db.accounts).get();
    final accountMap = <String, String>{
      for (final a in existingAccounts) a.name.toLowerCase(): a.id,
    };

    int importedCount = 0;

    await _db.transaction(() async {
      for (final item in items) {
        String? targetCategoryId = defaultCategoryId;

        if (item.categoryName != null && item.categoryName!.isNotEmpty) {
          final key = item.categoryName!.toLowerCase();
          if (categoryMap.containsKey(key)) {
            targetCategoryId = categoryMap[key];
          } else if (autoCreateCategories) {
            final newId = const Uuid().v4();
            await _db.into(_db.categories).insert(
                  CategoriesCompanion.insert(
                    id: newId,
                    name: item.categoryName!,
                    type: item.type,
                    icon: const Value('category'),
                    color: const Value(0xFF4CAF50),
                    isDefault: const Value(false),
                  ),
                );
            categoryMap[key] = newId;
            targetCategoryId = newId;
          }
        }

        String targetAccountId = defaultAccountId;
        if (item.accountName != null && item.accountName!.isNotEmpty) {
          final key = item.accountName!.toLowerCase();
          if (accountMap.containsKey(key)) {
            targetAccountId = accountMap[key]!;
          }
        }

        final txId = const Uuid().v4();
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: txId,
                title: item.title,
                amount: item.amount,
                type: item.type,
                categoryId: Value(targetCategoryId),
                accountId: targetAccountId,
                date: Value(item.date),
                note: Value(item.note),
                isSplit: const Value(false),
                createdAt: Value(DateTime.now()),
              ),
            );

        importedCount++;
      }
    });

    return importedCount;
  }

  DateTime _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();

    final cleanStr = dateStr.trim();
    // Common date formats
    final formats = [
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-ddTHH:mm:ss',
      'MMM d, yyyy',
      'd MMM yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(cleanStr);
      } catch (_) {}
    }

    return DateTime.tryParse(cleanStr) ?? DateTime.now();
  }

  double _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return 0.0;
    final cleaned = amountStr.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}

final importWizardServiceProvider = Provider<ImportWizardService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ImportWizardService(db);
});
