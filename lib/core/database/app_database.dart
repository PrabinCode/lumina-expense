import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'default_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Accounts, Categories, Transactions, Budgets, Debts, Goals])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'lumina_expense_db',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed default accounts
          await into(accounts).insert(
            AccountsCompanion.insert(
              id: DefaultData.defaultAccountId,
              name: 'Cash Wallet',
              type: 'cash',
              currency: const Value('USD'),
              icon: const Value('payments'),
              color: const Value(0xFF4CAF50),
              initialBalance: const Value(0.0),
            ),
          );
          await into(accounts).insert(
            AccountsCompanion.insert(
              id: DefaultData.defaultBankId,
              name: 'Bank Account',
              type: 'bank',
              currency: const Value('USD'),
              icon: const Value('account_balance'),
              color: const Value(0xFF2196F3),
              initialBalance: const Value(0.0),
            ),
          );

          // Seed default categories
          for (final cat in DefaultData.categories) {
            await into(categories).insert(
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
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(goals);
          }
        },
      );
}
