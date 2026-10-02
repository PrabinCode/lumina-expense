import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'default_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Accounts, Categories, Transactions, Budgets, Debts, Goals, TransactionSplits, RecurringTransactions, DeletedItems, DebtRepayments, GoalTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 6;

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
          if (from < 3) {
            await m.addColumn(transactions, transactions.isSplit);
            await m.createTable(transactionSplits);
          }
          if (from < 4) {
            await m.createTable(recurringTransactions);
          }
          if (from < 5) {
            await m.createTable(deletedItems);
          }
          if (from < 6) {
            await m.addColumn(debts, debts.date);
            await m.createTable(debtRepayments);
            await m.createTable(goalTransactions);
          }
        },
        beforeOpen: (details) async {
          // Performance indexes for frequent filters, foreign key lookups, and range queries
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_splits_tx ON transaction_splits(transaction_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_splits_cat ON transaction_splits(category_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_budgets_cat ON budgets(category_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_debts_settled ON debts(is_settled);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_debt_repayments_debt ON debt_repayments(debt_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_goal_tx_goal ON goal_transactions(goal_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_transactions(next_due_date, is_active);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_deleted_items_type ON deleted_items(entity_type);');
        },
      );
}
