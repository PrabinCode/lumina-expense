import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/categories/data/category_repository.dart';
import 'package:lumina_expense/features/recycle_bin/data/recycle_bin_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

void main() {
  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late RecycleBinRepository recycleRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    recycleRepo = RecycleBinRepository(db);

    // Insert a child category under cat_food_dining
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_fast_food',
            name: 'Fast Food',
            type: 'expense',
            parentCategoryId: const Value('cat_food_dining'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('getCategoryUsage accurately detects usage counts', () async {
    // Initially 0 usage for cat_food_dining
    var usage = await categoryRepo.getCategoryUsage('cat_food_dining');
    expect(usage.hasUsages, isFalse);
    expect(usage.transactionCount, 0);

    // Add 1 direct transaction
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            title: 'Burger joint',
            amount: 15.0,
            type: 'expense',
            accountId: 'cash_wallet',
            categoryId: const Value('cat_food_dining'),
          ),
        );

    // Add 1 budget
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            id: 'b-1',
            categoryId: 'cat_food_dining',
            amountLimit: 200.0,
          ),
        );

    usage = await categoryRepo.getCategoryUsage('cat_food_dining');
    expect(usage.hasUsages, isTrue);
    expect(usage.transactionCount, 1);
    expect(usage.budgetCount, 1);
    expect(usage.totalUsages, 2);
  });

  test('deleteCategoryWithReassignment reassigns transactions and re-parents subcategories', () async {
    // Add transaction under cat_food_dining
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            title: 'Dinner',
            amount: 50.0,
            type: 'expense',
            accountId: 'cash_wallet',
            categoryId: const Value('cat_food_dining'),
          ),
        );

    // Add budget
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            id: 'b-1',
            categoryId: 'cat_food_dining',
            amountLimit: 200.0,
          ),
        );

    // Delete and reassign to cat_groceries with deleteAssociatedBudget = true
    await categoryRepo.deleteCategoryWithReassignment(
      categoryId: 'cat_food_dining',
      targetCategoryId: 'cat_groceries',
      deleteAssociatedBudget: true,
    );

    // Category should be deleted
    final cat = await (db.select(db.categories)..where((c) => c.id.equals('cat_food_dining'))).getSingleOrNull();
    expect(cat, isNull);

    // Transaction should now point to cat_groceries
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-1'))).getSingle();
    expect(tx.categoryId, 'cat_groceries');

    // Budget should be deleted
    final budget = await (db.select(db.budgets)..where((b) => b.id.equals('b-1'))).getSingleOrNull();
    expect(budget, isNull);

    // Subcategory cat_fast_food should have parentCategoryId set to null
    final subCat = await (db.select(db.categories)..where((c) => c.id.equals('cat_fast_food'))).getSingle();
    expect(subCat.parentCategoryId, isNull);
  });

  test('deleteCategoryWithReassignment with null target un-categorizes transactions', () async {
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-2',
            title: 'Snack',
            amount: 5.0,
            type: 'expense',
            accountId: 'cash_wallet',
            categoryId: const Value('cat_food_dining'),
          ),
        );

    await categoryRepo.deleteCategoryWithReassignment(
      categoryId: 'cat_food_dining',
      targetCategoryId: null,
      deleteAssociatedBudget: false,
    );

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-2'))).getSingle();
    expect(tx.categoryId, isNull);
  });

  test('moveCategoryToRecycleBin and restoreItem restores category and transaction mappings', () async {
    // 1. Transaction under food_dining
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            title: 'Dinner',
            amount: 50.0,
            type: 'expense',
            accountId: 'cash_wallet',
            categoryId: const Value('cat_food_dining'),
          ),
        );

    final originalCat = await (db.select(db.categories)..where((c) => c.id.equals('cat_food_dining'))).getSingle();
    final affectedIds = await categoryRepo.getAssociatedTransactionIds('cat_food_dining');

    // 2. Move to recycle bin
    final recycleId = await recycleRepo.moveCategoryToRecycleBin(
      originalCat,
      affectedTransactionIds: affectedIds,
      reassignedToId: 'cat_groceries',
    );

    // Execute reassignment deletion
    await categoryRepo.deleteCategoryWithReassignment(
      categoryId: 'cat_food_dining',
      targetCategoryId: 'cat_groceries',
    );

    // Verify transaction now has cat_groceries
    var tx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-1'))).getSingle();
    expect(tx.categoryId, 'cat_groceries');

    // 3. Restore category from recycle bin
    final restored = await recycleRepo.restoreItem(recycleId);
    expect(restored, isTrue);

    // Verify category exists again
    final restoredCat = await (db.select(db.categories)..where((c) => c.id.equals('cat_food_dining'))).getSingleOrNull();
    expect(restoredCat, isNotNull);
    expect(restoredCat!.name, 'Food & Dining');

    // Verify transaction was restored back to cat_food_dining
    tx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-1'))).getSingle();
    expect(tx.categoryId, 'cat_food_dining');
  });
}
