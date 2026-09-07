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
    expect(txs.length, greaterThan(20));

    final budgets = await db.select(db.budgets).get();
    expect(budgets.length, greaterThanOrEqualTo(3));

    final debts = await db.select(db.debts).get();
    expect(debts.length, greaterThanOrEqualTo(3));

    final goals = await db.select(db.goals).get();
    expect(goals.length, greaterThanOrEqualTo(3));

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

    final initialDebts = await db.select(db.debts).get();
    final initialRepayments = await db.select(db.debtRepayments).get();
    final initialGoals = await db.select(db.goals).get();
    final initialGoalTxs = await db.select(db.goalTransactions).get();

    // Clear db
    await db.delete(db.transactions).go();
    await db.delete(db.debtRepayments).go();
    await db.delete(db.debts).go();
    await db.delete(db.goalTransactions).go();
    await db.delete(db.goals).go();

    final clearedTxs = await db.select(db.transactions).get();
    expect(clearedTxs.isEmpty, true);

    // Restore from file
    await backupService.restoreFromFile(filePath);
    final restoredTxs = await db.select(db.transactions).get();
    expect(restoredTxs.length, preview.transactionCount);

    final restoredDebts = await db.select(db.debts).get();
    expect(restoredDebts.length, initialDebts.length);

    final restoredRepayments = await db.select(db.debtRepayments).get();
    expect(restoredRepayments.length, initialRepayments.length);

    final restoredGoals = await db.select(db.goals).get();
    expect(restoredGoals.length, initialGoals.length);

    final restoredGoalTxs = await db.select(db.goalTransactions).get();
    expect(restoredGoalTxs.length, initialGoalTxs.length);

    tempDir.deleteSync(recursive: true);
  });

  test('Legacy backup without debtRepayments or goalTransactions restores safely', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_legacy_backup');
    final legacyFile = File('${tempDir.path}/legacy_backup.json');

    // Simulate an older schema backup (version 4/5 before repayments & goal transactions)
    final legacyJson = '''
{
  "version": 4,
  "appName": "LuminaExpense",
  "exportDate": "2025-01-01T00:00:00.000Z",
  "data": {
    "accounts": [
      {
        "id": "acc-1",
        "name": "Checking Account",
        "type": "bank",
        "initialBalance": 1000.0,
        "currency": "USD"
      }
    ],
    "categories": [],
    "transactions": [
      {
        "id": "tx-1",
        "title": "Grocery Shopping",
        "amount": 75.50,
        "type": "expense",
        "accountId": "acc-1",
        "date": "2025-01-01T12:00:00.000Z"
      }
    ],
    "transactionSplits": [],
    "budgets": [],
    "debts": [
      {
        "id": "debt-legacy-1",
        "personName": "Alice",
        "amount": 200.0,
        "settledAmount": 50.0,
        "type": "lent"
      }
    ],
    "goals": [
      {
        "id": "goal-legacy-1",
        "name": "Vacation Fund",
        "targetAmount": 1500.0,
        "currentAmount": 300.0
      }
    ]
  }
}
''';
    await legacyFile.writeAsString(legacyJson);

    // Restore legacy file into database
    await backupService.restoreFromFile(legacyFile.path);

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    expect(txs.first.title, 'Grocery Shopping');

    final debts = await db.select(db.debts).get();
    expect(debts.length, 1);
    expect(debts.first.personName, 'Alice');
    expect(debts.first.amount, 200.0);
    expect(debts.first.date, isNotNull); // Automatically defaulted without crashing

    final repayments = await db.select(db.debtRepayments).get();
    expect(repayments.isEmpty, true);

    final goals = await db.select(db.goals).get();
    expect(goals.length, 1);
    expect(goals.first.name, 'Vacation Fund');

    final goalTxs = await db.select(db.goalTransactions).get();
    expect(goalTxs.isEmpty, true);

    tempDir.deleteSync(recursive: true);
  });
}
