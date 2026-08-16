import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final int subscriptionCount;

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
    this.subscriptionCount = 0,
  });
}

class BackupFileInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;

  BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('MMM d, yyyy • hh:mm a').format(modifiedAt);
  }
}

class BackupRestoreService {
  static const _keyBackupDir = 'backup_storage_location';
  static const _keyAutoFrequency = 'backup_auto_frequency';
  static const _keyMaxFiles = 'backup_max_files';

  final AppDatabase _db;

  BackupRestoreService(this._db);

  /// Get the user-configured backup storage directory (or standard default)
  Future<String> getBackupStorageDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_keyBackupDir);

    if (customPath != null && customPath.trim().isNotEmpty) {
      final dir = Directory(customPath.trim());
      if (await dir.exists()) {
        return dir.path;
      }
    }

    // Default to /storage/emulated/0/Download/LuminaBackups on Android
    Directory defaultDir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download/LuminaBackups');
      defaultDir = downloadDir;
    } else {
      Directory? base;
      try {
        base = await getDownloadsDirectory();
      } catch (_) {}
      try {
        base ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      base ??= Directory.systemTemp;
      defaultDir = Directory('${base.path}/LuminaBackups');
    }

    if (!await defaultDir.exists()) {
      try {
        await defaultDir.create(recursive: true);
      } catch (_) {
        // Fallback to documents directory if permissions fail
        final fallback = await getApplicationDocumentsDirectory();
        return fallback.path;
      }
    }

    return defaultDir.path;
  }

  /// Save new backup storage location
  Future<void> setBackupStorageDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackupDir, path);
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Launch system folder picker to select storage location (like Mihon)
  Future<String?> pickAndSetStorageDirectory() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Backup Storage Location',
    );
    if (selected != null && selected.trim().isNotEmpty) {
      await setBackupStorageDirectory(selected.trim());
      return selected.trim();
    }
    return null;
  }

  /// List all local backup files in the configured storage directory
  Future<List<BackupFileInfo>> listLocalBackups() async {
    final dirPath = await getBackupStorageDirectory();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return [];
    }

    final entities = await dir.list().toList();
    final backups = <BackupFileInfo>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path.split(Platform.pathSeparator).last;

        backups.add(BackupFileInfo(
          path: entity.path,
          fileName: name,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ));
      }
    }

    // Sort newest first
    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  /// Delete a backup file
  Future<void> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Auto-backup frequency setting (off, daily, weekly)
  Future<String> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAutoFrequency) ?? 'off';
  }

  Future<void> setAutoBackupFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAutoFrequency, frequency);
  }

  /// Max backup files retention count
  Future<int> getMaxBackupFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxFiles) ?? 5;
  }

  Future<void> setMaxBackupFiles(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxFiles, count);
  }

  /// Generate Backup JSON payload
  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();
    final debts = await _db.select(_db.debts).get();
    final goals = await _db.select(_db.goals).get();
    final splits = await _db.select(_db.transactionSplits).get();
    final subscriptions = await _db.select(_db.recurringTransactions).get();

    return {
      'version': 4,
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
                  'isSplit': t.isSplit,
                  'createdAt': t.createdAt.toIso8601String(),
                })
            .toList(),
        'transactionSplits': splits
            .map((s) => {
                  'id': s.id,
                  'transactionId': s.transactionId,
                  'categoryId': s.categoryId,
                  'amount': s.amount,
                  'note': s.note,
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
        'recurringTransactions': subscriptions
            .map((s) => {
                  'id': s.id,
                  'title': s.title,
                  'amount': s.amount,
                  'categoryId': s.categoryId,
                  'accountId': s.accountId,
                  'frequency': s.frequency,
                  'interval': s.interval,
                  'nextDueDate': s.nextDueDate.toIso8601String(),
                  'autoLog': s.autoLog,
                  'isActive': s.isActive,
                  'notes': s.notes,
                  'createdAt': s.createdAt.toIso8601String(),
                })
            .toList(),
      }
    };
  }

  /// Create backup in configured storage location and auto-prune oldest
  Future<String> createBackup({String? targetDir}) async {
    final payload = await _buildBackupPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final dirPath = targetDir ?? await getBackupStorageDirectory();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/lumina_backup_$timestamp.json';

    final file = File(filePath);
    await file.writeAsString(jsonString);

    // Auto-prune old backups if limit is reached
    final maxFiles = await getMaxBackupFiles();
    final existing = await listLocalBackups();
    if (existing.length > maxFiles) {
      for (int i = maxFiles; i < existing.length; i++) {
        await deleteBackup(existing[i].path);
      }
    }

    return filePath;
  }

  /// Export Backup to temporary location and trigger Native Share Sheet
  Future<String> exportBackupJson() async {
    final payload = await _buildBackupPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${tempDir.path}/lumina_backup_$timestamp.json';

    final file = File(filePath);
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Lumina Expense Backup ($timestamp)',
      text: 'Lumina Expense offline database backup snapshot.',
    );

    return filePath;
  }

  /// Create CSV Export in configured directory
  Future<String> createCsvExport({String? targetDir}) async {
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
    final dirPath = targetDir ?? await getBackupStorageDirectory();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/transactions_$timestamp.csv';

    final file = File(filePath);
    await file.writeAsString(csvString);
    return filePath;
  }

  /// Share CSV Export via apps
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

  /// Inspect a backup file by path
  Future<BackupPreview> inspectBackupFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);

    if (!json.containsKey('data') || !json.containsKey('version')) {
      throw const FormatException('Invalid backup file structure.');
    }

    final data = json['data'] as Map<String, dynamic>;

    return BackupPreview(
      version: json['version'] as int? ?? 1,
      appName: json['appName'] as String? ?? 'Unknown',
      exportDate: DateTime.tryParse(json['exportDate'] as String? ?? '') ?? DateTime.now(),
      accountCount: (data['accounts'] as List?)?.length ?? 0,
      categoryCount: (data['categories'] as List?)?.length ?? 0,
      transactionCount: (data['transactions'] as List?)?.length ?? 0,
      budgetCount: (data['budgets'] as List?)?.length ?? 0,
      debtCount: (data['debts'] as List?)?.length ?? 0,
      goalCount: (data['goals'] as List?)?.length ?? 0,
      subscriptionCount: (data['recurringTransactions'] as List?)?.length ?? 0,
    );
  }

  /// Pick a backup file from anywhere via file picker
  Future<({String filePath, BackupPreview preview})?> pickAndInspectBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return null;
    }

    final path = result.files.single.path!;
    final preview = await inspectBackupFile(path);
    return (filePath: path, preview: preview);
  }

  /// Restore database from JSON backup file
  Future<void> restoreFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);
    final data = json['data'] as Map<String, dynamic>;

    await _db.transaction(() async {
      // 1. Clear existing data
      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.transactionSplits).go();
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
                isSplit: Value(t['isSplit'] ?? false),
                createdAt: Value(DateTime.tryParse(t['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 5. Insert Transaction Splits
      final splitsList = (data['transactionSplits'] as List? ?? []);
      for (final s in splitsList) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: s['id'],
                transactionId: s['transactionId'],
                categoryId: s['categoryId'],
                amount: (s['amount'] as num).toDouble(),
                note: Value(s['note']),
              ),
            );
      }

      // 6. Insert Budgets
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

      // 7. Insert Debts
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

      // 8. Insert Goals
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

      // 9. Insert Recurring Transactions (Subscriptions)
      final recurringList = (data['recurringTransactions'] as List? ?? []);
      for (final r in recurringList) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: r['id'],
                title: r['title'],
                amount: (r['amount'] as num).toDouble(),
                categoryId: r['categoryId'],
                accountId: r['accountId'],
                frequency: Value(r['frequency'] ?? 'monthly'),
                interval: Value(r['interval'] ?? 1),
                nextDueDate: DateTime.tryParse(r['nextDueDate'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
                autoLog: Value(r['autoLog'] ?? false),
                isActive: Value(r['isActive'] ?? true),
                notes: Value(r['notes']),
                createdAt: Value(DateTime.tryParse(r['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }
    });
  }

  /// Populate realistic Demo / Sample data
  Future<void> seedDemoData() async {
    const uuid = Uuid();
    final now = DateTime.now();

    await _db.transaction(() async {
      final existingCats = await _db.select(_db.categories).get();
      final catMap = {for (var c in existingCats) c.name: c.id};

      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.transactionSplits).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();

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

      final sampleTxs = [
        (title: 'Monthly Salary', amount: 3500.0, type: 'income', cat: 'Salary', daysAgo: 25),
        (title: 'Freelance Design Project', amount: 850.0, type: 'income', cat: 'Freelance & Projects', daysAgo: 10),
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

      // Sample Split Transaction
      final splitTxId = uuid.v4();
      final groceriesCatId = catMap['Groceries'];
      final diningCatId = catMap['Food & Dining'];

      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: splitTxId,
              title: 'Costco Superstore & Food Court',
              amount: 120.0,
              type: 'expense',
              accountId: bankAcc,
              isSplit: const Value(true),
              date: Value(now.subtract(const Duration(days: 3))),
            ),
          );

      if (groceriesCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTxId,
                categoryId: groceriesCatId,
                amount: 85.0,
                note: const Value('Pantry & Bulk Groceries'),
              ),
            );
      }

      if (diningCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTxId,
                categoryId: diningCatId,
                amount: 35.0,
                note: const Value('Food Court Pizza & Drinks'),
              ),
            );
      }

      // Sample Debts
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

      // Sample Goals
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

      // Sample Subscriptions
      final entertainmentCatId = catMap['Entertainment'];
      final billsCatId = catMap['Bills & Utilities'];

      if (entertainmentCatId != null) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Netflix Premium 4K',
                amount: 22.99,
                categoryId: entertainmentCatId,
                accountId: bankAcc,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 4)),
                autoLog: const Value(true),
                notes: const Value('Family subscription'),
              ),
            );

        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Spotify Duo',
                amount: 14.99,
                categoryId: entertainmentCatId,
                accountId: bankAcc,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 12)),
                autoLog: const Value(false),
                notes: const Value('Music streaming'),
              ),
            );
      }

      if (billsCatId != null) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Gigabit Fiber Internet',
                amount: 70.00,
                categoryId: billsCatId,
                accountId: bankAcc,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 18)),
                autoLog: const Value(true),
                notes: const Value('Home fiber broadband bill'),
              ),
            );
      }
    });
  }
}

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupRestoreService(db);
});
