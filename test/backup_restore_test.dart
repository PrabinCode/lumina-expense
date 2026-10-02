import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/services/receipt_storage_service.dart';
import 'package:lumina_expense/features/backup/services/backup_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupRestoreService backupService;
  late Directory mockTempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTempDir = Directory.systemTemp.createTempSync('lumina_mock_paths_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return mockTempDir.path;
      },
    );
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await db.close();
    if (mockTempDir.existsSync()) {
      mockTempDir.deleteSync(recursive: true);
    }
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

  test('Backup and restore preserves user settings and preferences (v6)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_name', 'Alex Johnson');
    await prefs.setString('user_profile_email', 'alex@example.com');
    await prefs.setString('selected_currency', 'EUR');
    await prefs.setString('theme_mode', 'dark');
    await prefs.setBool('privacy_mask_enabled', true);

    await backupService.seedDemoData();

    final tempDir = Directory.systemTemp.createTempSync('lumina_settings_test');
    final filePath = await backupService.createBackup(targetDir: tempDir.path);

    // Clear preferences
    await prefs.clear();
    expect(prefs.getString('user_profile_name'), isNull);
    expect(prefs.getString('selected_currency'), isNull);

    // Restore
    await backupService.restoreFromFile(filePath);

    expect(prefs.getString('user_profile_name'), 'Alex Johnson');
    expect(prefs.getString('user_profile_email'), 'alex@example.com');
    expect(prefs.getString('selected_currency'), 'EUR');
    expect(prefs.getString('theme_mode'), 'dark');
    expect(prefs.getBool('privacy_mask_enabled'), true);

    tempDir.deleteSync(recursive: true);
  });

  test('Multi-sheet Excel (.xlsx) export contains all 10 sheets with comprehensive data', () async {
    await backupService.seedDemoData();

    final tempDir = Directory.systemTemp.createTempSync('lumina_excel_test');
    final filePath = await backupService.createExcelExport(targetDir: tempDir.path);

    final file = File(filePath);
    expect(file.existsSync(), true);
    expect(file.lengthSync(), greaterThan(1000));
    expect(filePath.endsWith('.xlsx'), true);

    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    // Check that all 10 expected sheets are created
    final expectedSheets = [
      'Summary',
      'Transactions',
      'Accounts',
      'Budgets',
      'Debts & Loans',
      'Debt Repayments',
      'Savings Goals',
      'Goal Contributions',
      'Subscriptions',
      'Categories',
    ];

    for (final sheetName in expectedSheets) {
      expect(excel.tables.containsKey(sheetName), true, reason: 'Missing sheet: $sheetName');
      expect(excel.tables[sheetName]!.rows.isNotEmpty, true, reason: 'Sheet is empty: $sheetName');
    }

    // Verify transactions sheet has rows matching demo transactions
    final txSheet = excel.tables['Transactions']!;
    expect(txSheet.rows.length, greaterThan(20)); // Headers + rows

    // Verify accounts sheet has 4 accounts
    final accSheet = excel.tables['Accounts']!;
    expect(accSheet.rows.length, greaterThanOrEqualTo(5)); // Header + 4 accounts

    tempDir.deleteSync(recursive: true);
  });

  test('Encrypted backup requires password on inspection and restores cleanly with password', () async {
    await backupService.seedDemoData();

    final tempDir = Directory.systemTemp.createTempSync('lumina_encrypted_test');
    final filePath = await backupService.createBackup(
      targetDir: tempDir.path,
      password: 'SafePassword123!',
    );

    expect(File(filePath).existsSync(), true);
    expect(filePath.endsWith('.enc'), true);

    // Inspecting without password must throw PASSWORD_REQUIRED
    expect(
      () => backupService.inspectBackupFile(filePath),
      throwsA(isA<FormatException>()),
    );

    // Inspecting with wrong password throws FormatException
    expect(
      () => backupService.inspectBackupFile(filePath, password: 'WrongPassword'),
      throwsA(isA<FormatException>()),
    );

    // Inspecting with correct password succeeds
    final preview = await backupService.inspectBackupFile(filePath, password: 'SafePassword123!');
    expect(preview.appName, 'LuminaExpense');
    expect(preview.transactionCount, greaterThan(10));

    // Clear db and restore with correct password
    await db.delete(db.transactions).go();
    await backupService.restoreFromFile(filePath, password: 'SafePassword123!');

    final restoredTxs = await db.select(db.transactions).get();
    expect(restoredTxs.length, preview.transactionCount);

    tempDir.deleteSync(recursive: true);
  });

  test('Creates unified ZIP container (.lumina), bundles receipts, and restores extracted receipts', () async {
    await backupService.seedDemoData();

    // 1. Create a dummy receipt image file in the receipts directory
    final storage = ReceiptStorageService();
    final receiptsDir = await storage.getReceiptsDirectory();
    if (!receiptsDir.existsSync()) {
      receiptsDir.createSync(recursive: true);
    }
    final receiptFile = File('${receiptsDir.path}/receipt_test_photo.jpg');
    await receiptFile.writeAsBytes(List.filled(256, 123));

    // 2. Attach receipt to a transaction
    final txs = await db.select(db.transactions).get();
    final firstTx = txs.first;
    await (db.update(db.transactions)..where((t) => t.id.equals(firstTx.id))).write(
      TransactionsCompanion(
        receiptPath: Value('receipts/receipt_test_photo.jpg'),
      ),
    );

    // 3. Create backup container (.lumina)
    final tempDir = Directory.systemTemp.createTempSync('lumina_container_test');
    final filePath = await backupService.createBackup(targetDir: tempDir.path);

    expect(File(filePath).existsSync(), true);
    expect(filePath.endsWith('.lumina'), true);

    // 4. Inspect container preview
    final preview = await backupService.inspectBackupFile(filePath);
    expect(preview.isContainer, true);
    expect(preview.hasImages, true);
    expect(preview.receiptCount, 1);
    expect(preview.receiptSizeBytes, 256);

    // 5. Delete local receipt and clear db
    await receiptFile.delete();
    expect(receiptFile.existsSync(), false);
    await db.delete(db.transactions).go();

    // 6. Restore from .lumina archive
    await backupService.restoreFromFile(filePath);

    // 7. Verify transaction restored with receipt path and physical file restored on disk!
    final restoredTx = await (db.select(db.transactions)..where((t) => t.id.equals(firstTx.id))).getSingle();
    expect(restoredTx.receiptPath, 'receipts/receipt_test_photo.jpg');

    final restoredReceiptFile = await storage.resolveReceiptFile(restoredTx.receiptPath);
    expect(restoredReceiptFile, isNotNull);
    expect(restoredReceiptFile!.existsSync(), true);
    expect(await restoredReceiptFile.length(), 256);

    tempDir.deleteSync(recursive: true);
  });

  test('Creates encrypted ZIP container (.lumina.enc), bundles receipts, and restores with password', () async {
    await backupService.seedDemoData();

    final storage = ReceiptStorageService();
    final receiptsDir = await storage.getReceiptsDirectory();
    if (!receiptsDir.existsSync()) {
      receiptsDir.createSync(recursive: true);
    }
    final receiptFile = File('${receiptsDir.path}/receipt_enc_photo.jpg');
    await receiptFile.writeAsBytes(List.filled(512, 77));

    final txs = await db.select(db.transactions).get();
    final firstTx = txs.first;
    await (db.update(db.transactions)..where((t) => t.id.equals(firstTx.id))).write(
      TransactionsCompanion(
        receiptPath: Value('receipts/receipt_enc_photo.jpg'),
      ),
    );

    final tempDir = Directory.systemTemp.createTempSync('lumina_enc_container_test');
    final filePath = await backupService.createBackup(
      targetDir: tempDir.path,
      password: 'SecretPassword99!',
    );

    expect(filePath.endsWith('.lumina.enc'), true);

    final preview = await backupService.inspectBackupFile(filePath, password: 'SecretPassword99!');
    expect(preview.isContainer, true);
    expect(preview.hasImages, true);
    expect(preview.receiptCount, 1);
    expect(preview.receiptSizeBytes, 512);

    await receiptFile.delete();
    await db.delete(db.transactions).go();

    await backupService.restoreFromFile(filePath, password: 'SecretPassword99!');

    final restoredReceiptFile = await storage.resolveReceiptFile('receipts/receipt_enc_photo.jpg');
    expect(restoredReceiptFile, isNotNull);
    expect(restoredReceiptFile!.existsSync(), true);
    expect(await restoredReceiptFile.length(), 512);

    tempDir.deleteSync(recursive: true);
  });
}
