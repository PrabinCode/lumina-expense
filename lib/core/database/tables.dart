import 'package:drift/drift.dart';

/// Accounts / Wallets Table
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // 'cash', 'bank', 'creditCard', 'savings', 'other'
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF2196F3))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories Table
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // 'expense' or 'income'
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF4CAF50))();
  TextColumn get parentCategoryId => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactions Table (Income, Expense, Transfer)
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'expense', 'income', 'transfer'
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  @ReferenceName('sourceTransactions')
  TextColumn get accountId => text().references(Accounts, #id)();

  @ReferenceName('destinationTransactions')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().nullable()(); // Comma-separated tags
  TextColumn get receiptPath => text().nullable()();
  BoolColumn get isSplit => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transaction Splits Table (Subcategory / Item breakdown for a single transaction)
class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Budgets Table
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amountLimit => real()();
  TextColumn get period => text().withDefault(const Constant('monthly'))(); // 'weekly', 'monthly', 'yearly'
  DateTimeColumn get startDate => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Debt / Lending (IOU) Table
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get personName => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  RealColumn get settledAmount => real().withDefault(const Constant(0.0))();
  TextColumn get type => text()(); // 'lent' (they owe me) or 'borrowed' (I owe them)
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Repayments / Installments history for Debts & Loans (IOUs)
class DebtRepayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text().references(Debts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Savings Goals & Sinking Funds Table
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get iconName => text().withDefault(const Constant('savings'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF10B981))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Deposit and Withdrawal history for Savings Goals
class GoalTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // 'deposit' or 'withdraw'
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Subscriptions & Recurring Transactions Table
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get frequency => text().withDefault(const Constant('monthly'))(); // 'daily', 'weekly', 'monthly', 'yearly'
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get autoLog => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Recycle Bin / Soft-Deleted Items Table
class DeletedItems extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()(); // 'transaction', 'budget', 'goal', 'debt', 'subscription', 'category'
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get subtitle => text().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get payloadJson => text()(); // Serialized snapshot of entity & any relations (e.g. splits)
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}


