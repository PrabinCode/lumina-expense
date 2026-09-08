import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'app_database.dart';
import '../providers/database_provider.dart';

class StorageStats {
  final int databaseSizeBytes;
  final int walSizeBytes;
  final int receiptsSizeBytes;
  final int cacheSizeBytes;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int budgetCount;
  final int debtCount;
  final int goalCount;
  final int subscriptionCount;
  final int recycleBinCount;
  final int receiptCount;
  final int orphanedReceiptCount;

  StorageStats({
    required this.databaseSizeBytes,
    this.walSizeBytes = 0,
    this.receiptsSizeBytes = 0,
    required this.cacheSizeBytes,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.budgetCount,
    required this.debtCount,
    required this.goalCount,
    required this.subscriptionCount,
    this.recycleBinCount = 0,
    this.receiptCount = 0,
    this.orphanedReceiptCount = 0,
  });

  int get totalSizeBytes => databaseSizeBytes + walSizeBytes + receiptsSizeBytes + cacheSizeBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class DatabaseMaintenanceService {
  final AppDatabase _db;

  DatabaseMaintenanceService(this._db);

  /// Calculate live database file size, WAL size, receipts footprint, row counts, and cache footprint
  Future<StorageStats> getStorageStats() async {
    int dbSize = 0;
    int walSize = 0;
    int cacheSize = 0;
    int receiptsSize = 0;
    int receiptFilesCount = 0;
    int orphanedReceipts = 0;

    // 1. Locate and measure SQLite database & WAL files
    try {
      final docDir = await getApplicationDocumentsDirectory();
      Directory? supportDir;
      try {
        supportDir = await getApplicationSupportDirectory();
      } catch (_) {}

      final candidateDirs = [docDir, ?supportDir];
      final dbBaseNames = ['lumina_expense_db.sqlite', 'lumina_expense.db', 'lumina_expense_db'];

      for (final dir in candidateDirs) {
        for (final base in dbBaseNames) {
          final mainFile = File(p.join(dir.path, base));
          if (await mainFile.exists()) {
            dbSize += await mainFile.length();
          }
          final walFile = File(p.join(dir.path, '$base-wal'));
          if (await walFile.exists()) {
            walSize += await walFile.length();
          }
          final shmFile = File(p.join(dir.path, '$base-shm'));
          if (await shmFile.exists()) {
            walSize += await shmFile.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error inspecting database file size: $e');
    }

    // 2. Locate and measure Receipt photo attachments
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(docDir.path, 'receipts'));
      if (await receiptsDir.exists()) {
        final activeReceiptPaths = await _getActiveReceiptNames();

        await for (final entity in receiptsDir.list(followLinks: false)) {
          if (entity is File) {
            final len = await entity.length();
            receiptsSize += len;
            receiptFilesCount++;
            final baseName = p.basename(entity.path);
            if (!activeReceiptPaths.contains(baseName)) {
              orphanedReceipts++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error inspecting receipts storage: $e');
    }

    // 3. Cache directory size
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        cacheSize = await _getDirSize(tempDir);
      }
    } catch (_) {}

    // 4. Row counts
    final txCount = await _countRows(_db.transactions);
    final accCount = await _countRows(_db.accounts);
    final catCount = await _countRows(_db.categories);
    final budCount = await _countRows(_db.budgets);
    final debtCount = await _countRows(_db.debts);
    final goalCount = await _countRows(_db.goals);
    final subCount = await _countRows(_db.recurringTransactions);
    final recycleCount = await _countRows(_db.deletedItems);

    return StorageStats(
      databaseSizeBytes: dbSize,
      walSizeBytes: walSize,
      receiptsSizeBytes: receiptsSize,
      cacheSizeBytes: cacheSize,
      transactionCount: txCount,
      accountCount: accCount,
      categoryCount: catCount,
      budgetCount: budCount,
      debtCount: debtCount,
      goalCount: goalCount,
      subscriptionCount: subCount,
      recycleBinCount: recycleCount,
      receiptCount: receiptFilesCount,
      orphanedReceiptCount: orphanedReceipts,
    );
  }

  /// Get set of active receipt filenames from transactions and recycle bin payloads
  Future<Set<String>> _getActiveReceiptNames() async {
    final names = <String>{};
    try {
      final query = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.receiptPath])
        ..where(_db.transactions.receiptPath.isNotNull());
      final rows = await query.map((row) => row.read(_db.transactions.receiptPath)).get();
      for (final r in rows) {
        if (r != null && r.trim().isNotEmpty) {
          names.add(p.basename(r.trim()));
        }
      }

      // Check soft-deleted items
      final delQuery = _db.selectOnly(_db.deletedItems)..addColumns([_db.deletedItems.payloadJson]);
      final delRows = await delQuery.map((row) => row.read(_db.deletedItems.payloadJson)).get();
      for (final jsonStr in delRows) {
        if (jsonStr != null && jsonStr.contains('receiptPath')) {
          try {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            final txData = decoded['transaction'] as Map<String, dynamic>?;
            final path = txData?['receiptPath'] as String?;
            if (path != null && path.trim().isNotEmpty) {
              names.add(p.basename(path.trim()));
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error querying active receipts: $e');
    }
    return names;
  }

  Future<int> _countRows(TableInfo table) async {
    try {
      final query = _db.selectOnly(table)..addColumns([countAll()]);
      final result = await query.map((row) => row.read(countAll())).getSingle();
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  /// Run SQLite WAL checkpoint, VACUUM, and ANALYZE to reclaim disk space, consolidate journals, and optimize indexes
  Future<int> runVacuumAndAnalyze() async {
    final beforeStats = await getStorageStats();
    final beforeTotal = beforeStats.databaseSizeBytes + beforeStats.walSizeBytes;

    try {
      // 1. Truncate WAL to write changes into main DB file
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      // 2. Reclaim free space and rebuild SQLite B-Trees
      await _db.customStatement('VACUUM;');
      // 3. Update query planner index statistics
      await _db.customStatement('ANALYZE;');
      // 4. Final truncate
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (e) {
      debugPrint('Error during SQLite VACUUM: $e');
    }

    final afterStats = await getStorageStats();
    final afterTotal = afterStats.databaseSizeBytes + afterStats.walSizeBytes;
    final reclaimed = beforeTotal - afterTotal;
    return reclaimed > 0 ? reclaimed : 0;
  }

  /// Run SQLite PRAGMA integrity_check
  Future<String> checkIntegrity() async {
    try {
      final rows = await _db.customSelect('PRAGMA integrity_check;').get();
      if (rows.isNotEmpty) {
        final result = rows.first.data.values.first.toString();
        return result;
      }
      return 'ok';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Clean temporary export files and application cache
  Future<int> cleanCache() async {
    int purgedBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is File) {
            purgedBytes += await entity.length();
            await entity.delete();
          } else if (entity is Directory) {
            purgedBytes += await _getDirSize(entity);
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (_) {}
    return purgedBytes;
  }

  /// Clean orphaned receipt images from receipts directory that are no longer referenced anywhere
  Future<({int purgedBytes, int purgedCount})> cleanOrphanedReceipts() async {
    int purgedBytes = 0;
    int purgedCount = 0;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(docDir.path, 'receipts'));
      if (await receiptsDir.exists()) {
        final activeReceiptPaths = await _getActiveReceiptNames();

        await for (final entity in receiptsDir.list(followLinks: false)) {
          if (entity is File) {
            final baseName = p.basename(entity.path);
            if (!activeReceiptPaths.contains(baseName)) {
              final len = await entity.length();
              await entity.delete();
              purgedBytes += len;
              purgedCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning orphaned receipts: $e');
    }

    return (purgedBytes: purgedBytes, purgedCount: purgedCount);
  }

  /// Empty all soft-deleted records from the Recycle Bin and cleanup their receipts
  Future<int> emptyRecycleBin() async {
    try {
      // First find any receipts in deleted items
      final docDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(docDir.path, 'receipts'));

      final delItems = await _db.select(_db.deletedItems).get();
      for (final item in delItems) {
        if (item.entityType == 'transaction' && item.payloadJson.contains('receiptPath')) {
          try {
            final decoded = jsonDecode(item.payloadJson) as Map<String, dynamic>;
            final txData = decoded['transaction'] as Map<String, dynamic>?;
            final path = txData?['receiptPath'] as String?;
            if (path != null && path.trim().isNotEmpty) {
              final f = File(p.join(receiptsDir.path, p.basename(path.trim())));
              if (await f.exists()) {
                await f.delete();
              }
            }
          } catch (_) {}
        }
      }

      return await _db.delete(_db.deletedItems).go();
    } catch (e) {
      debugPrint('Error emptying recycle bin: $e');
      return 0;
    }
  }
}

final databaseMaintenanceServiceProvider = Provider<DatabaseMaintenanceService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DatabaseMaintenanceService(db);
});

