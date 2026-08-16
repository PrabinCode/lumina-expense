import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class BackupPreview {
  final int version;
  final String appName;
  final DateTime exportDate;
  final int accountCount;
  final int categoryCount;
  final int transactionCount;
  final int budgetCount;
  final int debtCount;
  final int goalCount;

  BackupPreview({
    required this.version,
    required this.appName,
    required this.exportDate,
    required this.accountCount,
    required this.categoryCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.debtCount,
    this.goalCount = 0,
  });
}

class BackupRestoreService {
  final AppDatabase _db;

  BackupRestoreService(this._db);

  /// 1. Export entire database to JSON and trigger Native Share Sheet (Google Drive, Files, etc.)
  Future<String> exportBackupJson() async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();
    final debts = await _db.select(_db.debts).get();
    final goals = await _db.select(_db.goals).get();

    final backupPayload = {
      'version': 2,
      'appName': 'LuminaExpense',
      'exportDate': DateTime.now().toIso8601String(),
      'data': {
        'accounts': accounts
            .map((a) => {
                  'id': a.id,
                  'name': a.name,
                  'type': a.type,
                  'initialBalance': a.initialBalance,
                  'currency': a.currency,
                  'icon': a.icon,
                  'color': a.color,
                  'isArchived': a.isArchived,
                  'createdAt': a.createdAt.toIso8601String(),
                })
            .toList(),
        'categories': categories
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'type': c.type,
                  'icon': c.icon,
                  'color': c.color,
                  'parentCategoryId': c.parentCategoryId,
                  'isDefault': c.isDefault,
                })
            .toList(),
        'transactions': transactions
            .map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'amount': t.amount,
                  'type': t.type,
                  'categoryId': t.categoryId,
                  'accountId': t.accountId,
                  'toAccountId': t.toAccountId,
                  'date': t.date.toIso8601String(),
                  'note': t.note,
                  'tags': t.tags,
                  'receiptPath': t.receiptPath,
                  'createdAt': t.createdAt.toIso8601String(),
                })
            .toList(),
        'budgets': budgets
            .map((b) => {
                  'id': b.id,
                  'categoryId': b.categoryId,
                  'amountLimit': b.amountLimit,
                  'period': b.period,
                  'startDate': b.startDate.toIso8601String(),
                })
            .toList(),
        'debts': debts
            .map((d) => {
                  'id': d.id,
                  'personName': d.personName,
                  'amount': d.amount,
                  'settledAmount': d.settledAmount,
                  'type': d.type,
                  'accountId': d.accountId,
                  'dueDate': d.dueDate?.toIso8601String(),
                  'isSettled': d.isSettled,
                  'notes': d.notes,
                  'createdAt': d.createdAt.toIso8601String(),
                })
            .toList(),
        'goals': goals
            .map((g) => {
                  'id': g.id,
                  'name': g.name,
                  'targetAmount': g.targetAmount,
                  'currentAmount': g.currentAmount,
                  'targetDate': g.targetDate?.toIso8601String(),
                  'iconName': g.iconName,
                  'colorValue': g.colorValue,
                  'notes': g.notes,
                  'isCompleted': g.isCompleted,
                  'createdAt': g.createdAt.toIso8601String(),
                })
            .toList(),
      }
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupPayload);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${tempDir.path}/lumina_backup_$timestamp.json';

    final file = File(filePath);
    await file.writeAsString(jsonString);

    // Share via native share sheet
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Lumina Expense Backup ($timestamp)',
      text: 'Lumina Expense offline database backup file.',
    );

    return filePath;
  }

  /// 2. Export Transactions to CSV (Excel / Sheets compatible)
  Future<String> exportTransactionsCsv() async {
    final cat = _db.categories;
    final srcAcc = _db.alias(_db.accounts, 'src');
    final dstAcc = _db.alias(_db.accounts, 'dst');

    final rows = await (_db.select(_db.transactions).join([
      leftOuterJoin(cat, cat.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(srcAcc, srcAcc.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(dstAcc, dstAcc.id.equalsExp(_db.transactions.toAccountId)),
    ])
          ..orderBy([OrderingTerm(expression: _db.transactions.date, mode: OrderingMode.desc)]))
        .get();

    final List<List<dynamic>> csvData = [
      ['Date', 'Time', 'Title', 'Type', 'Category', 'Account', 'Transfer To', 'Amount', 'Currency', 'Notes', 'Tags']
    ];

    for (final row in rows) {
      final t = row.readTable(_db.transactions);
      final c = row.readTableOrNull(cat);
      final src = row.readTable(srcAcc);
      final dst = row.readTableOrNull(dstAcc);

      csvData.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        DateFormat('HH:mm:ss').format(t.date),
        t.title,
        t.type.toUpperCase(),
        c?.name ?? (t.type == 'transfer' ? 'Transfer' : 'Uncategorized'),
        src.name,
        dst?.name ?? '',
        t.amount,
        src.currency,
        t.note ?? '',
        t.tags ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${tempDir.path}/transactions_$timestamp.csv';

    final file = File(filePath);
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Transactions CSV Export ($timestamp)',
      text: 'Exported transaction history.',
    );

    return filePath;
  }

  /// 3. Pick a backup file and inspect its contents
  Future<({String filePath, BackupPreview preview})?> pickAndInspectBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return null;
    }

    final path = result.files.single.path!;
    final file = File(path);
    final content = await file.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);

    if (!json.containsKey('data') || !json.containsKey('version')) {
      throw const FormatException('Invalid backup file structure.');
    }

    final data = json['data'] as Map<String, dynamic>;

    final preview = BackupPreview(
      version: json['version'] as int? ?? 1,
      appName: json['appName'] as String? ?? 'Unknown',
      exportDate: DateTime.tryParse(json['exportDate'] as String? ?? '') ?? DateTime.now(),
      accountCount: (data['accounts'] as List?)?.length ?? 0,
      categoryCount: (data['categories'] as List?)?.length ?? 0,
      transactionCount: (data['transactions'] as List?)?.length ?? 0,
      budgetCount: (data['budgets'] as List?)?.length ?? 0,
      debtCount: (data['debts'] as List?)?.length ?? 0,
      goalCount: (data['goals'] as List?)?.length ?? 0,
    );

    return (filePath: path, preview: preview);
  }

  /// 4. Restore database from JSON backup file
  Future<void> restoreFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);
    final data = json['data'] as Map<String, dynamic>;

    await _db.transaction(() async {
      // 1. Clear existing data
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();

      // 2. Insert Accounts
      final accountsList = (data['accounts'] as List? ?? []);
      for (final a in accountsList) {
        await _db.into(_db.accounts).insert(
              AccountsCompanion.insert(
                id: a['id'],
                name: a['name'],
                type: a['type'],
                initialBalance: Value((a['initialBalance'] as num?)?.toDouble() ?? 0.0),
                currency: Value(a['currency'] ?? 'USD'),
                icon: Value(a['icon'] ?? 'wallet'),
                color: Value(a['color'] ?? 0xFF2196F3),
                isArchived: Value(a['isArchived'] ?? false),
                createdAt: Value(DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 3. Insert Categories
      final categoriesList = (data['categories'] as List? ?? []);
      for (final c in categoriesList) {
        await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                id: c['id'],
                name: c['name'],
                type: c['type'],
                icon: Value(c['icon'] ?? 'category'),
                color: Value(c['color'] ?? 0xFF4CAF50),
                parentCategoryId: Value(c['parentCategoryId']),
                isDefault: Value(c['isDefault'] ?? false),
              ),
            );
      }

      // 4. Insert Transactions
      final transactionsList = (data['transactions'] as List? ?? []);
      for (final t in transactionsList) {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: t['id'],
                title: t['title'],
                amount: (t['amount'] as num).toDouble(),
                type: t['type'],
                categoryId: Value(t['categoryId']),
                accountId: t['accountId'],
                toAccountId: Value(t['toAccountId']),
                date: Value(DateTime.tryParse(t['date'] ?? '') ?? DateTime.now()),
                note: Value(t['note']),
                tags: Value(t['tags']),
                receiptPath: Value(t['receiptPath']),
                createdAt: Value(DateTime.tryParse(t['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 5. Insert Budgets
      final budgetsList = (data['budgets'] as List? ?? []);
      for (final b in budgetsList) {
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                id: b['id'],
                categoryId: b['categoryId'],
                amountLimit: (b['amountLimit'] as num).toDouble(),
                period: Value(b['period'] ?? 'monthly'),
                startDate: Value(DateTime.tryParse(b['startDate'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 6. Insert Debts
      final debtsList = (data['debts'] as List? ?? []);
      for (final d in debtsList) {
        await _db.into(_db.debts).insert(
              DebtsCompanion.insert(
                id: d['id'],
                personName: d['personName'],
                amount: (d['amount'] as num).toDouble(),
                settledAmount: Value((d['settledAmount'] as num?)?.toDouble() ?? 0.0),
                type: d['type'],
                accountId: Value(d['accountId']),
                dueDate: Value(d['dueDate'] != null ? DateTime.tryParse(d['dueDate']) : null),
                isSettled: Value(d['isSettled'] ?? false),
                notes: Value(d['notes']),
                createdAt: Value(DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 7. Insert Goals
      final goalsList = (data['goals'] as List? ?? []);
      for (final g in goalsList) {
        await _db.into(_db.goals).insert(
              GoalsCompanion.insert(
                id: g['id'],
                name: g['name'],
                targetAmount: (g['targetAmount'] as num).toDouble(),
                currentAmount: Value((g['currentAmount'] as num?)?.toDouble() ?? 0.0),
                targetDate: Value(g['targetDate'] != null ? DateTime.tryParse(g['targetDate']) : null),
                iconName: Value(g['iconName'] ?? 'savings'),
                colorValue: Value(g['colorValue'] ?? 0xFF10B981),
                notes: Value(g['notes']),
                isCompleted: Value(g['isCompleted'] ?? false),
                createdAt: Value(DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }
    });
  }

  /// 5. Populate realistic Demo / Sample data for quick testing and open-source demonstration
  Future<void> seedDemoData() async {
    const uuid = Uuid();
    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. Ensure Categories exist
      final existingCats = await _db.select(_db.categories).get();
      final catMap = {for (var c in existingCats) c.name: c.id};

      // 2. Clear old transactions, debts, goals
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();

      // 3. Create Sample Budgets
      if (catMap.containsKey('Food & Dining')) {
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                id: uuid.v4(),
                categoryId: catMap['Food & Dining']!,
                amountLimit: 400.0,
              ),
            );
      }
      if (catMap.containsKey('Groceries')) {
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                id: uuid.v4(),
                categoryId: catMap['Groceries']!,
                amountLimit: 350.0,
              ),
            );
      }
      if (catMap.containsKey('Entertainment')) {
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                id: uuid.v4(),
                categoryId: catMap['Entertainment']!,
                amountLimit: 150.0,
              ),
            );
      }

      // 4. Sample Transactions across the past 30 days
      final sampleTxs = [
        // Salary
        (title: 'Monthly Salary', amount: 3500.0, type: 'income', cat: 'Salary', daysAgo: 25),
        (title: 'Freelance Design Project', amount: 850.0, type: 'income', cat: 'Freelance & Projects', daysAgo: 10),
        // Expenses
        (title: 'Supermarket Weekly Groceries', amount: 112.50, type: 'expense', cat: 'Groceries', daysAgo: 1),
        (title: 'Coffee & Breakfast', amount: 8.50, type: 'expense', cat: 'Food & Dining', daysAgo: 1),
        (title: 'Dinner with Friends', amount: 48.00, type: 'expense', cat: 'Food & Dining', daysAgo: 2),
        (title: 'Gasoline refill', amount: 45.00, type: 'expense', cat: 'Transportation', daysAgo: 3),
        (title: 'Apartment Rent', amount: 1200.0, type: 'expense', cat: 'Housing & Rent', daysAgo: 15),
        (title: 'High-speed Internet Bill', amount: 60.00, type: 'expense', cat: 'Bills & Utilities', daysAgo: 12),
        (title: 'Netflix & Spotify Subscriptions', amount: 25.98, type: 'expense', cat: 'Entertainment', daysAgo: 8),
        (title: 'Pharmacy Vitamins', amount: 32.40, type: 'expense', cat: 'Health & Medical', daysAgo: 5),
        (title: 'Running Shoes', amount: 85.00, type: 'expense', cat: 'Shopping', daysAgo: 7),
        (title: 'Weekend Taxi', amount: 18.20, type: 'expense', cat: 'Transportation', daysAgo: 4),
        (title: 'Lunch Burrito Bowl', amount: 14.50, type: 'expense', cat: 'Food & Dining', daysAgo: 0),
      ];

      final accounts = await _db.select(_db.accounts).get();
      final defaultAcc = accounts.isNotEmpty ? accounts.first.id : 'acc_default_cash';
      final bankAcc = accounts.length > 1 ? accounts[1].id : defaultAcc;

      for (final item in sampleTxs) {
        final categoryId = catMap[item.cat];
        final targetAcc = item.type == 'income' ? bankAcc : (item.amount > 50 ? bankAcc : defaultAcc);

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: uuid.v4(),
                title: item.title,
                amount: item.amount,
                type: item.type,
                categoryId: Value(categoryId),
                accountId: targetAcc,
                date: Value(now.subtract(Duration(days: item.daysAgo))),
              ),
            );
      }

      // 5. Sample Debts (IOUs)
      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: uuid.v4(),
              personName: 'Alex Smith',
              amount: 75.0,
              settledAmount: const Value(25.0),
              type: 'lent',
              notes: const Value('Concert tickets booking split'),
              dueDate: Value(now.add(const Duration(days: 7))),
            ),
          );

      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: uuid.v4(),
              personName: 'Sarah Jenkins',
              amount: 50.0,
              settledAmount: const Value(0.0),
              type: 'borrowed',
              notes: const Value('Weekend road trip fuel share'),
              dueDate: Value(now.add(const Duration(days: 14))),
            ),
          );

      // 6. Sample Goals (Sinking Funds)
      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: uuid.v4(),
              name: 'Emergency Fund',
              targetAmount: 5000.0,
              currentAmount: const Value(3200.0),
              iconName: const Value('favorite'),
              colorValue: const Value(0xFF10B981),
              targetDate: Value(now.add(const Duration(days: 180))),
            ),
          );

      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: uuid.v4(),
              name: 'New MacBook Pro',
              targetAmount: 2000.0,
              currentAmount: const Value(1250.0),
              iconName: const Value('laptop'),
              colorValue: const Value(0xFF3B82F6),
              targetDate: Value(now.add(const Duration(days: 90))),
            ),
          );
    });
  }
}

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupRestoreService(db);
});
