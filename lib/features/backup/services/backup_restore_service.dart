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
import '../../../core/database/default_data.dart';
import '../../../core/providers/database_provider.dart';
import 'backup_crypto_service.dart';


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
  final bool isEncrypted;
  final bool isAuto;

  BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
    this.isEncrypted = false,
    this.isAuto = false,
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
  static const _keyLastAutoBackup = 'backup_last_auto_timestamp';

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

  /// Launch system folder picker to select storage location
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
      if (entity is File && (entity.path.endsWith('.json') || entity.path.endsWith('.enc') || entity.path.endsWith('.lumina.enc'))) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path.split(Platform.pathSeparator).last;
        final isEncrypted = entity.path.endsWith('.enc') || entity.path.endsWith('.lumina.enc');
        final isAuto = name.toLowerCase().contains('_auto_') || name.toLowerCase().startsWith('lumina_backup_auto');

        backups.add(BackupFileInfo(
          path: entity.path,
          fileName: name,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          isEncrypted: isEncrypted,
          isAuto: isAuto,
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

  /// Get the timestamp of the last recorded automatic backup
  Future<DateTime?> getLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastAutoBackup);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  /// Record the timestamp of an automatic backup
  Future<void> recordAutoBackupTimestamp([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastAutoBackup, (time ?? DateTime.now()).toIso8601String());
  }

  /// Check schedule and perform automatic backup if due.
  Future<bool> checkAndPerformAutoBackup() async {
    final freq = await getAutoBackupFrequency();
    if (freq == 'off') return false;

    final lastTime = await getLastAutoBackupTime();
    final now = DateTime.now();

    bool shouldRun = false;
    if (lastTime == null) {
      shouldRun = true;
    } else {
      final diff = now.difference(lastTime);
      if (freq == 'daily' && diff.inHours >= 24) {
        shouldRun = true;
      } else if (freq == 'weekly' && diff.inDays >= 7) {
        shouldRun = true;
      }
    }

    if (shouldRun) {
      await createBackup(isAuto: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastAutoBackup, now.toIso8601String());
      return true;
    }
    return false;
  }

  /// Generate Backup JSON payload
  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();
    final debts = await _db.select(_db.debts).get();
    final debtRepayments = await _db.select(_db.debtRepayments).get();
    final goals = await _db.select(_db.goals).get();
    final goalTransactions = await _db.select(_db.goalTransactions).get();
    final splits = await _db.select(_db.transactionSplits).get();
    final subscriptions = await _db.select(_db.recurringTransactions).get();

    return {
      'version': 5,
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
                  'date': d.date.toIso8601String(),
                  'dueDate': d.dueDate?.toIso8601String(),
                  'isSettled': d.isSettled,
                  'notes': d.notes,
                  'createdAt': d.createdAt.toIso8601String(),
                })
            .toList(),
        'debtRepayments': debtRepayments
            .map((r) => {
                  'id': r.id,
                  'debtId': r.debtId,
                  'amount': r.amount,
                  'date': r.date.toIso8601String(),
                  'notes': r.notes,
                  'createdAt': r.createdAt.toIso8601String(),
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
        'goalTransactions': goalTransactions
            .map((t) => {
                  'id': t.id,
                  'goalId': t.goalId,
                  'type': t.type,
                  'amount': t.amount,
                  'date': t.date.toIso8601String(),
                  'notes': t.notes,
                  'createdAt': t.createdAt.toIso8601String(),
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
        'deletedItems': (await _db.select(_db.deletedItems).get())
            .map((d) => {
                  'id': d.id,
                  'entityId': d.entityId,
                  'entityType': d.entityType,
                  'title': d.title,
                  'subtitle': d.subtitle,
                  'amount': d.amount,
                  'payloadJson': d.payloadJson,
                  'deletedAt': d.deletedAt.toIso8601String(),
                })
            .toList(),
      }
    };
  }

  /// Create backup in configured storage location and auto-prune oldest auto-backups
  Future<String> createBackup({String? targetDir, String? password, bool isAuto = false}) async {
    final payload = await _buildBackupPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final dirPath = targetDir ?? await getBackupStorageDirectory();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final isEnc = password != null && password.trim().isNotEmpty;
    final prefix = isAuto ? 'lumina_backup_auto' : 'lumina_backup_manual';
    final fileName = isEnc ? '${prefix}_$timestamp.lumina.enc' : '${prefix}_$timestamp.json';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    if (isEnc) {
      final encrypted = BackupCryptoService.encryptJson(jsonString, password.trim());
      await file.writeAsString(encrypted);
    } else {
      await file.writeAsString(jsonString);
    }

    // Auto-prune old AUTO backups ONLY if limit is reached (manual backups are preserved)
    final maxFiles = await getMaxBackupFiles();
    final existing = await listLocalBackups();
    final autoBackups = existing.where((b) => b.isAuto).toList();
    if (autoBackups.length > maxFiles) {
      for (int i = maxFiles; i < autoBackups.length; i++) {
        await deleteBackup(autoBackups[i].path);
      }
    }

    return filePath;
  }

  /// Export Backup to temporary location and trigger Native Share Sheet
  Future<String> exportBackupJson({String? password}) async {
    final payload = await _buildBackupPayload();
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final isEnc = password != null && password.trim().isNotEmpty;
    final fileName = isEnc ? 'lumina_backup_$timestamp.lumina.enc' : 'lumina_backup_$timestamp.json';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    if (isEnc) {
      final encrypted = BackupCryptoService.encryptJson(jsonString, password.trim());
      await file.writeAsString(encrypted);
    } else {
      await file.writeAsString(jsonString);
    }

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Lumina Expense Backup ($timestamp)',
      text: isEnc ? 'Lumina Expense encrypted database backup snapshot.' : 'Lumina Expense offline database backup snapshot.',
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

  /// Inspect a backup file by path (supports encrypted and unencrypted backups)
  Future<BackupPreview> inspectBackupFile(String filePath, {String? password}) async {
    final file = File(filePath);
    String content = await file.readAsString();

    if (BackupCryptoService.isEncrypted(content)) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('PASSWORD_REQUIRED');
      }
      content = BackupCryptoService.decryptJson(content, password.trim());
    }

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
  Future<({String filePath, BackupPreview preview, bool isEncrypted})?> pickAndInspectBackup({String? password}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'enc'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return null;
    }

    final path = result.files.single.path!;
    final file = File(path);
    final content = await file.readAsString();
    final isEnc = BackupCryptoService.isEncrypted(content) || path.endsWith('.enc');

    final preview = await inspectBackupFile(path, password: password);
    return (filePath: path, preview: preview, isEncrypted: isEnc);
  }

  /// Restore database from JSON backup file
  Future<void> restoreFromFile(String filePath, {String? password}) async {
    final file = File(filePath);
    String content = await file.readAsString();

    if (BackupCryptoService.isEncrypted(content)) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('PASSWORD_REQUIRED');
      }
      content = BackupCryptoService.decryptJson(content, password.trim());
    }

    final Map<String, dynamic> json = jsonDecode(content);
    final data = json['data'] as Map<String, dynamic>;


    await _db.transaction(() async {
      // 1. Clear existing data
      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.transactionSplits).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.debtRepayments).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goalTransactions).go();
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
                date: Value(d['date'] != null ? (DateTime.tryParse(d['date']) ?? DateTime.now()) : DateTime.now()),
                dueDate: Value(d['dueDate'] != null ? DateTime.tryParse(d['dueDate']) : null),
                isSettled: Value(d['isSettled'] ?? false),
                notes: Value(d['notes']),
                createdAt: Value(DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now()),
              ),
            );
      }

      // 7b. Insert Debt Repayments
      final debtRepaymentsList = (data['debtRepayments'] as List? ?? []);
      for (final r in debtRepaymentsList) {
        await _db.into(_db.debtRepayments).insert(
              DebtRepaymentsCompanion.insert(
                id: r['id'],
                debtId: r['debtId'],
                amount: (r['amount'] as num).toDouble(),
                date: Value(DateTime.tryParse(r['date'] ?? '') ?? DateTime.now()),
                notes: Value(r['notes']),
                createdAt: Value(DateTime.tryParse(r['createdAt'] ?? '') ?? DateTime.now()),
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

      // 8b. Insert Goal Transactions
      final goalTransactionsList = (data['goalTransactions'] as List? ?? []);
      for (final t in goalTransactionsList) {
        await _db.into(_db.goalTransactions).insert(
              GoalTransactionsCompanion.insert(
                id: t['id'],
                goalId: t['goalId'],
                type: t['type'] ?? 'deposit',
                amount: (t['amount'] as num).toDouble(),
                date: Value(DateTime.tryParse(t['date'] ?? '') ?? DateTime.now()),
                notes: Value(t['notes']),
                createdAt: Value(DateTime.tryParse(t['createdAt'] ?? '') ?? DateTime.now()),
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

      // 10. Insert Deleted Items (Recycle Bin)
      await _db.delete(_db.deletedItems).go();
      final deletedList = (data['deletedItems'] as List? ?? []);
      for (final d in deletedList) {
        await _db.into(_db.deletedItems).insert(
              DeletedItemsCompanion.insert(
                id: d['id'],
                entityId: d['entityId'],
                entityType: d['entityType'],
                title: d['title'],
                subtitle: Value(d['subtitle']),
                amount: Value((d['amount'] as num?)?.toDouble()),
                payloadJson: d['payloadJson'],
                deletedAt: Value(DateTime.tryParse(d['deletedAt'] ?? '') ?? DateTime.now()),
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
      // 1. Clear all existing data
      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.transactionSplits).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();

      // 2. Insert Standard Categories
      for (final cat in DefaultData.categories) {
        await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                id: cat.id,
                name: cat.name,
                type: cat.type,
                icon: Value(cat.icon),
                color: Value(cat.color),
                isDefault: const Value(true),
              ),
            );
      }

      final existingCats = await _db.select(_db.categories).get();
      final catMap = {for (var c in existingCats) c.name: c.id};

      // 3. Insert Realistic Accounts
      const bankAccId = DefaultData.defaultBankId;
      const cashAccId = DefaultData.defaultAccountId;
      const savingsAccId = 'acc_high_yield_savings';
      const creditAccId = 'acc_rewards_credit';

      await _db.into(_db.accounts).insert(
            AccountsCompanion.insert(
              id: bankAccId,
              name: 'Main Checking Account',
              type: 'bank',
              initialBalance: const Value(4250.00),
              currency: const Value('USD'),
              icon: const Value('account_balance'),
              color: const Value(0xFF1E88E5),
            ),
          );

      await _db.into(_db.accounts).insert(
            AccountsCompanion.insert(
              id: cashAccId,
              name: 'Daily Cash Wallet',
              type: 'cash',
              initialBalance: const Value(320.00),
              currency: const Value('USD'),
              icon: const Value('account_balance_wallet'),
              color: const Value(0xFF43A047),
            ),
          );

      await _db.into(_db.accounts).insert(
            AccountsCompanion.insert(
              id: savingsAccId,
              name: 'High-Yield Savings',
              type: 'savings',
              initialBalance: const Value(8500.00),
              currency: const Value('USD'),
              icon: const Value('savings'),
              color: const Value(0xFFFB8C00),
            ),
          );

      await _db.into(_db.accounts).insert(
            AccountsCompanion.insert(
              id: creditAccId,
              name: 'Rewards Credit Card',
              type: 'credit',
              initialBalance: const Value(0.00),
              currency: const Value('USD'),
              icon: const Value('credit_card'),
              color: const Value(0xFF8E24AA),
            ),
          );

      // 4. Insert Active Monthly Budgets
      final budgetConfigs = [
        ('Food & Dining', 450.0),
        ('Groceries', 400.0),
        ('Shopping', 250.0),
        ('Entertainment', 150.0),
        ('Transportation', 200.0),
      ];

      for (final b in budgetConfigs) {
        final catId = catMap[b.$1];
        if (catId != null) {
          await _db.into(_db.budgets).insert(
                BudgetsCompanion.insert(
                  id: uuid.v4(),
                  categoryId: catId,
                  amountLimit: b.$2,
                ),
              );
        }
      }

      // 5. Insert Rich Historical Transactions (Past 30 Days)
      final sampleTxs = [
        // Income entries
        (title: 'Tech Lead Monthly Salary', amount: 4500.0, type: 'income', cat: 'Salary', acc: bankAccId, daysAgo: 25, tags: '#work,#salary', note: 'Direct deposit paycheck'),
        (title: 'Freelance Mobile UI/UX Project', amount: 1250.0, type: 'income', cat: 'Freelance & Projects', acc: bankAccId, daysAgo: 12, tags: '#freelance', note: 'Client milestone completion payment'),
        (title: 'Quarterly S&P500 Dividends', amount: 185.40, type: 'income', cat: 'Investments & Dividends', acc: savingsAccId, daysAgo: 18, tags: '#investments', note: 'Vanguard portfolio dividend distribution'),
        (title: 'Birthday Gift from Family', amount: 100.0, type: 'income', cat: 'Gifts & Grants', acc: cashAccId, daysAgo: 6, tags: '#gift', note: 'Birthday card cash'),

        // Housing & Fixed Bills
        (title: 'Downtown Apartment Monthly Lease', amount: 1350.0, type: 'expense', cat: 'Housing & Rent', acc: bankAccId, daysAgo: 24, tags: '#rent,#essential', note: 'Monthly apartment rent transfer'),
        (title: 'High-speed Fiber Internet (1Gbps)', amount: 70.0, type: 'expense', cat: 'Bills & Utilities', acc: bankAccId, daysAgo: 15, tags: '#bills', note: 'Home broadband connection'),
        (title: 'Clean Energy Electric Utility', amount: 85.40, type: 'expense', cat: 'Bills & Utilities', acc: bankAccId, daysAgo: 10, tags: '#utilities', note: 'Monthly electricity consumption'),
        (title: 'Unlimited 5G Mobile Plan', amount: 45.0, type: 'expense', cat: 'Bills & Utilities', acc: bankAccId, daysAgo: 8, tags: '#bills', note: 'Carrier phone bill'),

        // Groceries & Food
        (title: 'Whole Foods Market Weekly Stockup', amount: 142.60, type: 'expense', cat: 'Groceries', acc: creditAccId, daysAgo: 2, tags: '#groceries', note: 'Organic fruits, vegetables, olive oil & chicken'),
        (title: "Trader Joe's Healthy Snacks & Bakery", amount: 58.30, type: 'expense', cat: 'Groceries', acc: creditAccId, daysAgo: 7, tags: '#groceries', note: 'Almond butter, trail mix, sourdough bread'),
        (title: 'Local Artisan French Bakery', amount: 14.20, type: 'expense', cat: 'Groceries', acc: cashAccId, daysAgo: 1, tags: '#bakery', note: 'Croissants and fresh baguette'),
        (title: 'Artisan Espresso & Morning Pastry', amount: 7.50, type: 'expense', cat: 'Food & Dining', acc: cashAccId, daysAgo: 0, tags: '#coffee,#lifestyle', note: 'Morning caffeine boost'),
        (title: 'Chipotle Burrito Bowl & Guacamole', amount: 15.80, type: 'expense', cat: 'Food & Dining', acc: creditAccId, daysAgo: 1, tags: '#dining', note: 'Quick lunch break'),
        (title: 'Italian Trattoria Dinner with Friends', amount: 68.00, type: 'expense', cat: 'Food & Dining', acc: creditAccId, daysAgo: 4, tags: '#dining,#social', note: 'Woodfired pizza, pasta & wine'),
        (title: 'Downtown Sushi Omakase Lunch', amount: 84.50, type: 'expense', cat: 'Food & Dining', acc: creditAccId, daysAgo: 14, tags: '#dining', note: 'Business lunch meeting'),

        // Transportation
        (title: 'Shell Gasoline Full Tank Refill', amount: 52.00, type: 'expense', cat: 'Transportation', acc: creditAccId, daysAgo: 3, tags: '#car,#fuel', note: 'Premium unleaded fuel'),
        (title: 'City Metro Transit Monthly Card', amount: 90.00, type: 'expense', cat: 'Transportation', acc: bankAccId, daysAgo: 20, tags: '#commute', note: 'Public transit subway pass'),
        (title: 'Uber Ride to Airport Terminal', amount: 34.50, type: 'expense', cat: 'Transportation', acc: creditAccId, daysAgo: 9, tags: '#travel,#taxi', note: 'Early morning airport transfer'),

        // Entertainment & Shopping
        (title: 'IMAX Cinema Tickets & Popcorn Combo', amount: 38.00, type: 'expense', cat: 'Entertainment', acc: creditAccId, daysAgo: 5, tags: '#entertainment,#movies', note: 'Sci-fi movie premiere night'),
        (title: 'Steam Games Summer Showcase Bundle', amount: 49.99, type: 'expense', cat: 'Entertainment', acc: creditAccId, daysAgo: 16, tags: '#gaming', note: 'Indie game package'),
        (title: 'Nike Pegasus Running Shoes', amount: 110.00, type: 'expense', cat: 'Shopping', acc: creditAccId, daysAgo: 11, tags: '#fitness,#shopping', note: 'Marathon training footwear'),
        (title: 'UNIQLO Merino Wool Knit Sweater', amount: 49.90, type: 'expense', cat: 'Shopping', acc: creditAccId, daysAgo: 19, tags: '#clothes', note: 'Autumn wardrobe staple'),
        (title: 'Amazon Ergonomic Vertical Mouse', amount: 65.00, type: 'expense', cat: 'Shopping', acc: creditAccId, daysAgo: 13, tags: '#work,#office', note: 'Home desk ergonomic upgrade'),

        // Health, Personal & Education
        (title: 'CVS Pharmacy Vitamins & Cold Relief', amount: 28.75, type: 'expense', cat: 'Health & Medical', acc: creditAccId, daysAgo: 6, tags: '#health', note: 'Multivitamins & zinc tablets'),
        (title: 'Routine Dental Hygiene Checkup', amount: 75.00, type: 'expense', cat: 'Health & Medical', acc: bankAccId, daysAgo: 21, tags: '#health,#dental', note: 'Annual preventative dental cleaning'),
        (title: 'Udemy Mobile Architecture Masterclass', amount: 19.99, type: 'expense', cat: 'Education', acc: creditAccId, daysAgo: 17, tags: '#learning,#education', note: 'Online development course'),
        (title: 'Gentlemen Barbershop Haircut & Styling', amount: 35.00, type: 'expense', cat: 'Personal Care', acc: cashAccId, daysAgo: 2, tags: '#grooming', note: 'Haircut and beard trim'),
      ];

      for (final item in sampleTxs) {
        final categoryId = catMap[item.cat];
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: uuid.v4(),
                title: item.title,
                amount: item.amount,
                type: item.type,
                categoryId: Value(categoryId),
                accountId: item.acc,
                date: Value(now.subtract(Duration(days: item.daysAgo))),
                tags: Value(item.tags),
                note: Value(item.note),
                isSplit: const Value(false),
                createdAt: Value(now.subtract(Duration(days: item.daysAgo))),
              ),
            );
      }

      // 6. Insert Multiple Itemized Split Transactions
      final splitTx1Id = uuid.v4();
      final groceriesCatId = catMap['Groceries'];
      final diningCatId = catMap['Food & Dining'];
      final utilitiesCatId = catMap['Bills & Utilities'];
      final healthCatId = catMap['Health & Medical'];
      final transportCatId = catMap['Transportation'];
      final entertainmentCatId = catMap['Entertainment'];


      // Split 1: Costco Superstore ($185.00)
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: splitTx1Id,
              title: 'Costco Wholesale Club Superstore',
              amount: 185.0,
              type: 'expense',
              accountId: creditAccId,
              isSplit: const Value(true),
              date: Value(now.subtract(const Duration(days: 3))),
              tags: const Value('#bulk,#shopping'),
              note: const Value('Monthly Costco household and groceries haul'),
            ),
          );

      if (groceriesCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx1Id,
                categoryId: groceriesCatId,
                amount: 115.0,
                note: const Value('Pantry staples, organic eggs, salmon & berries'),
              ),
            );
      }
      if (utilitiesCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx1Id,
                categoryId: utilitiesCatId,
                amount: 45.0,
                note: const Value('Bulk laundry detergent & paper towels'),
              ),
            );
      }
      if (healthCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx1Id,
                categoryId: healthCatId,
                amount: 25.0,
                note: const Value('Electrolyte powder & multivitamin gummies'),
              ),
            );
      }

      // Split 2: Weekend Mountain Trip Split ($240.00)
      final splitTx2Id = uuid.v4();
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: splitTx2Id,
              title: 'Weekend Mountain Cabin Getaway',
              amount: 240.0,
              type: 'expense',
              accountId: creditAccId,
              isSplit: const Value(true),
              date: Value(now.subtract(const Duration(days: 15))),
              tags: const Value('#vacation,#trip'),
              note: const Value('Cabin rental expenses shared with friends'),
            ),
          );

      if (transportCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx2Id,
                categoryId: transportCatId,
                amount: 70.0,
                note: const Value('Highway toll passes & SUV fuel'),
              ),
            );
      }
      if (diningCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx2Id,
                categoryId: diningCatId,
                amount: 120.0,
                note: const Value('Group BBQ cookout & rustic pub dinner'),
              ),
            );
      }
      if (entertainmentCatId != null) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: uuid.v4(),
                transactionId: splitTx2Id,
                categoryId: entertainmentCatId,
                amount: 50.0,
                note: const Value('National park trail admission & boat rental'),
              ),
            );
      }

      // 7. Insert Realistic Financial Goals
      final emergencyGoalId = uuid.v4();
      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: emergencyGoalId,
              name: '🛡️ Emergency Reserve (6 Mo)',
              targetAmount: 10000.0,
              currentAmount: const Value(6850.0),
              iconName: const Value('savings'),
              colorValue: const Value(0xFF10B981), // Emerald
              targetDate: Value(now.add(const Duration(days: 180))),
              notes: const Value('Dedicated safety buffer in high-yield account'),
            ),
          );

      await _db.into(_db.goalTransactions).insert(
            GoalTransactionsCompanion.insert(
              id: uuid.v4(),
              goalId: emergencyGoalId,
              type: 'deposit',
              amount: 5000.0,
              date: Value(now.subtract(const Duration(days: 45))),
              notes: const Value('Initial emergency fund transfer from old bank'),
            ),
          );
      await _db.into(_db.goalTransactions).insert(
            GoalTransactionsCompanion.insert(
              id: uuid.v4(),
              goalId: emergencyGoalId,
              type: 'deposit',
              amount: 1850.0,
              date: Value(now.subtract(const Duration(days: 15))),
              notes: const Value('Quarterly performance bonus deposit'),
            ),
          );

      final macGoalId = uuid.v4();
      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: macGoalId,
              name: '💻 MacBook Pro M3 Max',
              targetAmount: 2499.0,
              currentAmount: const Value(1800.0),
              iconName: const Value('laptop'),
              colorValue: const Value(0xFF3B82F6), // Blue
              targetDate: Value(now.add(const Duration(days: 60))),
              notes: const Value('Workstation upgrade for development & design'),
            ),
          );

      await _db.into(_db.goalTransactions).insert(
            GoalTransactionsCompanion.insert(
              id: uuid.v4(),
              goalId: macGoalId,
              type: 'deposit',
              amount: 1000.0,
              date: Value(now.subtract(const Duration(days: 30))),
              notes: const Value('Freelance UI project payout'),
            ),
          );
      await _db.into(_db.goalTransactions).insert(
            GoalTransactionsCompanion.insert(
              id: uuid.v4(),
              goalId: macGoalId,
              type: 'deposit',
              amount: 800.0,
              date: Value(now.subtract(const Duration(days: 10))),
              notes: const Value('Monthly tech fund allocation'),
            ),
          );

      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: uuid.v4(),
              name: '✈️ Tokyo & Kyoto Autumn Trip',
              targetAmount: 3500.0,
              currentAmount: const Value(1450.0),
              iconName: const Value('flight'),
              colorValue: const Value(0xFFEC4899), // Pink
              targetDate: Value(now.add(const Duration(days: 120))),
              notes: const Value('Flights, hotels & Japan Rail pass'),
            ),
          );

      await _db.into(_db.goals).insert(
            GoalsCompanion.insert(
              id: uuid.v4(),
              name: '🚗 EV Vehicle Downpayment',
              targetAmount: 5000.0,
              currentAmount: const Value(4850.0),
              iconName: const Value('directions_car'),
              colorValue: const Value(0xFFF59E0B), // Amber
              targetDate: Value(now.add(const Duration(days: 30))),
              notes: const Value('Almost ready for order deposit'),
            ),
          );

      // 8. Insert Realistic Debts & IOUs
      final alexDebtId = uuid.v4();
      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: alexDebtId,
              personName: 'Alex Morgan',
              amount: 120.0,
              settledAmount: const Value(40.0),
              type: 'lent',
              date: Value(now.subtract(const Duration(days: 14))),
              notes: const Value('Concert VIP tickets front booking'),
              dueDate: Value(now.add(const Duration(days: 7))),
            ),
          );

      await _db.into(_db.debtRepayments).insert(
            DebtRepaymentsCompanion.insert(
              id: uuid.v4(),
              debtId: alexDebtId,
              amount: 40.0,
              date: Value(now.subtract(const Duration(days: 4))),
              notes: const Value('First installment via Venmo'),
            ),
          );

      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: uuid.v4(),
              personName: 'Michael Chang',
              amount: 65.0,
              settledAmount: const Value(0.0),
              type: 'lent',
              date: Value(now.subtract(const Duration(days: 5))),
              notes: const Value('Team dinner bill coverage'),
              dueDate: Value(now.add(const Duration(days: 10))),
            ),
          );

      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: uuid.v4(),
              personName: 'Sarah Jenkins',
              amount: 50.0,
              settledAmount: const Value(0.0),
              type: 'borrowed',
              date: Value(now.subtract(const Duration(days: 2))),
              notes: const Value('Weekend road trip fuel share'),
              dueDate: Value(now.add(const Duration(days: 14))),
            ),
          );

      final emmaDebtId = uuid.v4();
      await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              id: emmaDebtId,
              personName: 'Emma Davis',
              amount: 45.0,
              settledAmount: const Value(45.0),
              isSettled: const Value(true),
              type: 'lent',
              date: Value(now.subtract(const Duration(days: 20))),
              notes: const Value('Book club supplies - fully repaid ✓'),
              dueDate: Value(now.subtract(const Duration(days: 5))),
            ),
          );

      await _db.into(_db.debtRepayments).insert(
            DebtRepaymentsCompanion.insert(
              id: uuid.v4(),
              debtId: emmaDebtId,
              amount: 45.0,
              date: Value(now.subtract(const Duration(days: 5))),
              notes: const Value('Cash settlement in full'),
            ),
          );

      // 9. Insert Recurring Subscriptions & Scheduled Bills
      if (entertainmentCatId != null) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Netflix Premium 4K Ultra HD',
                amount: 22.99,
                categoryId: entertainmentCatId,
                accountId: bankAccId,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 3)),
                autoLog: const Value(true),
                notes: const Value('Family 4-screen plan'),
              ),
            );

        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Spotify Family Premium',
                amount: 16.99,
                categoryId: entertainmentCatId,
                accountId: bankAccId,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 11)),
                autoLog: const Value(true),
                notes: const Value('High fidelity music streaming'),
              ),
            );
      }

      if (utilitiesCatId != null) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Gigabit Fiber Broadband',
                amount: 70.00,
                categoryId: utilitiesCatId,
                accountId: bankAccId,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 16)),
                autoLog: const Value(true),
                notes: const Value('Home fiber connection'),
              ),
            );

        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'iCloud+ 2TB Family Storage',
                amount: 9.99,
                categoryId: utilitiesCatId,
                accountId: bankAccId,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 8)),
                autoLog: const Value(true),
                notes: const Value('Cloud backup & Photo sync'),
              ),
            );
      }

      if (healthCatId != null) {
        await _db.into(_db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                id: uuid.v4(),
                title: 'Planet Fitness Black Card',
                amount: 24.99,
                categoryId: healthCatId,
                accountId: bankAccId,
                frequency: const Value('monthly'),
                nextDueDate: now.add(const Duration(days: 22)),
                autoLog: const Value(true),
                notes: const Value('Gym & spa access membership'),
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
