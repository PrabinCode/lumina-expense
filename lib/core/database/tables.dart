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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

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
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
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

