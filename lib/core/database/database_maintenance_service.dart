import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'app_database.dart';
import '../providers/database_provider.dart';

class StorageStats {
  final int databaseSizeBytes;
  final int cacheSizeBytes;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int budgetCount;
  final int debtCount;
  final int goalCount;
  final int subscriptionCount;

  StorageStats({
    required this.databaseSizeBytes,
    required this.cacheSizeBytes,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.budgetCount,
    required this.debtCount,
    required this.goalCount,
    required this.subscriptionCount,
  });

  int get totalSizeBytes => databaseSizeBytes + cacheSizeBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class DatabaseMaintenanceService {
  final AppDatabase _db;

  DatabaseMaintenanceService(this._db);

  /// Calculate live database file size, row counts, and cache footprint
  Future<StorageStats> getStorageStats() async {
    int dbSize = 0;
    int cacheSize = 0;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(docDir.path, 'lumina_expense.db'));
      if (await dbFile.exists()) {
        dbSize = await dbFile.length();
      }
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        cacheSize = await _getDirSize(tempDir);
      }
    } catch (_) {}

    final txCount = await _countRows(_db.transactions);
    final accCount = await _countRows(_db.accounts);
    final catCount = await _countRows(_db.categories);
    final budCount = await _countRows(_db.budgets);
    final debtCount = await _countRows(_db.debts);
    final goalCount = await _countRows(_db.goals);
    final subCount = await _countRows(_db.recurringTransactions);

    return StorageStats(
      databaseSizeBytes: dbSize,
      cacheSizeBytes: cacheSize,
      transactionCount: txCount,
      accountCount: accCount,
      categoryCount: catCount,
      budgetCount: budCount,
      debtCount: debtCount,
      goalCount: goalCount,
      subscriptionCount: subCount,
    );
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

  /// Run SQLite VACUUM and ANALYZE to reclaim unallocated pages and optimize query index statistics
  Future<int> runVacuumAndAnalyze() async {
    final beforeStats = await getStorageStats();
    try {
      await _db.customStatement('VACUUM;');
      await _db.customStatement('ANALYZE;');
    } catch (_) {}
    final afterStats = await getStorageStats();
    final reclaimed = beforeStats.databaseSizeBytes - afterStats.databaseSizeBytes;
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
}

final databaseMaintenanceServiceProvider = Provider<DatabaseMaintenanceService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DatabaseMaintenanceService(db);
});
