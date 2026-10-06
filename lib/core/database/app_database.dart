import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'default_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UserProfiles,
  Accounts,
  Categories,
  Transactions,
  Budgets,
  Debts,
  Goals,
  TransactionSplits,
  RecurringTransactions,
  DeletedItems,
  DebtRepayments,
  GoalTransactions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 7;

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
          // Seed default user profile
          await into(userProfiles).insert(
            UserProfilesCompanion.insert(
              id: 'default_profile',
              name: 'Personal',
              email: const Value(null),
              icon: const Value('person'),
              color: const Value(0xFF10B981),
              currency: const Value('USD'),
              isDefault: const Value(true),
            ),
          );

          // Seed default accounts
          await into(accounts).insert(
            AccountsCompanion.insert(
              id: DefaultData.defaultAccountId,
              profileId: const Value('default_profile'),
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
              profileId: const Value('default_profile'),
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
                profileId: const Value('default_profile'),
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
          if (from < 7) {
            await m.createTable(userProfiles);
            await m.addColumn(accounts, accounts.profileId);
            await m.addColumn(categories, categories.profileId);
            await m.addColumn(transactions, transactions.profileId);
            await m.addColumn(budgets, budgets.profileId);
            await m.addColumn(debts, debts.profileId);
            await m.addColumn(goals, goals.profileId);
            await m.addColumn(recurringTransactions, recurringTransactions.profileId);
            await m.addColumn(deletedItems, deletedItems.profileId);

            // Create initial default profile if none exists
            await customStatement('''
              INSERT OR IGNORE INTO user_profiles (id, name, email, icon, color, currency, is_default, created_at)
              VALUES ('default_profile', 'Personal', NULL, 'person', 4279310209, 'USD', 1, strftime('%s', 'now'));
            ''');

            // Backfill existing rows with default_profile
            await customStatement("UPDATE accounts SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE categories SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE transactions SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE budgets SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE debts SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE goals SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE recurring_transactions SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
            await customStatement("UPDATE deleted_items SET profile_id = 'default_profile' WHERE profile_id IS NULL OR profile_id = '';");
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

          // Multi-profile performance indexes
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_profile_date ON transactions(profile_id, date);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_accounts_profile ON accounts(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_categories_profile ON categories(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_budgets_profile ON budgets(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_debts_profile ON debts(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_goals_profile ON goals(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_recurring_profile ON recurring_transactions(profile_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_deleted_profile ON deleted_items(profile_id);');
        },
      );
}
