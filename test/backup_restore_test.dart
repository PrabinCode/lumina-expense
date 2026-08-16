import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/backup/services/backup_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupRestoreService backupService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Seed demo data populates categories, transactions, budgets, and debts', () async {
    await backupService.seedDemoData();

    final txs = await db.select(db.transactions).get();
    expect(txs.length, greaterThan(5));

    final budgets = await db.select(db.budgets).get();
    expect(budgets.length, greaterThan(1));

    final debts = await db.select(db.debts).get();
    expect(debts.length, 2);

    final goals = await db.select(db.goals).get();
    expect(goals.length, 2);
  });

  test('Create backup, inspect metadata preview, and restore to empty db', () async {
    await backupService.seedDemoData();

    final tempDir = Directory.systemTemp.createTempSync('lumina_test_backup');
    final filePath = await backupService.createBackup(targetDir: tempDir.path);

    expect(File(filePath).existsSync(), true);

    // Inspect preview
    final preview = await backupService.inspectBackupFile(filePath);
    expect(preview.appName, 'LuminaExpense');
    expect(preview.transactionCount, greaterThan(5));
    expect(preview.accountCount, greaterThan(0));

    // Clear db
    await db.delete(db.transactions).go();
    final clearedTxs = await db.select(db.transactions).get();
    expect(clearedTxs.isEmpty, true);

    // Restore from file
    await backupService.restoreFromFile(filePath);
    final restoredTxs = await db.select(db.transactions).get();
    expect(restoredTxs.length, preview.transactionCount);

    tempDir.deleteSync(recursive: true);
  });
}
