import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/backup/services/backup_restore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupRestoreService backupService;

  setUp(() {
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
  });
}
