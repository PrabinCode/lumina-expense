import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/utils/query_parser.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  group('QueryParser Tests', () {
    final account = Account(
      id: 'acc1',
      name: 'Chase Bank',
      type: 'bank',
      initialBalance: 1000.0,
      currency: 'USD',
      icon: 'account_balance',
      color: 0xFF2196F3,
      isArchived: false,
      createdAt: DateTime.now(),
    );

    final category = Category(
      id: 'cat1',
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      color: 0xFF4CAF50,
      parentCategoryId: null,
      isDefault: true,
    );

    final transaction = Transaction(
      id: 'tx1',
      title: 'Whole Foods Organic Groceries',
      amount: 85.50,
      type: 'expense',
      categoryId: 'cat1',
      accountId: 'acc1',
      toAccountId: null,
      date: DateTime(2026, 8, 20),
      note: 'Weekly family restock',
      tags: 'organic,family',
      receiptPath: null,
      isSplit: false,
      createdAt: DateTime.now(),
    );

    final item = TransactionWithDetails(
      transaction: transaction,
      category: category,
      account: account,
    );

    test('empty query matches all', () {
      expect(QueryParser.evaluate('', item), isTrue);
      expect(QueryParser.evaluate('   ', item), isTrue);
    });

    test('free text matching', () {
      expect(QueryParser.evaluate('organic', item), isTrue);
      expect(QueryParser.evaluate('whole foods', item), isTrue);
      expect(QueryParser.evaluate('walmart', item), isFalse);
    });

    test('category prefix matching', () {
      expect(QueryParser.evaluate('cat:Groceries', item), isTrue);
      expect(QueryParser.evaluate('cat:Food', item), isFalse);
      expect(QueryParser.evaluate('cat:"Groceries"', item), isTrue);
    });

    test('account prefix matching', () {
      expect(QueryParser.evaluate('acc:Chase', item), isTrue);
      expect(QueryParser.evaluate('acc:Cash', item), isFalse);
    });

    test('amount comparison operators', () {
      expect(QueryParser.evaluate('amount:>50', item), isTrue);
      expect(QueryParser.evaluate('amount:>=85.50', item), isTrue);
      expect(QueryParser.evaluate('amount:<50', item), isFalse);
      expect(QueryParser.evaluate('>80', item), isTrue);
      expect(QueryParser.evaluate('<=85.5', item), isTrue);
    });

    test('negation matching', () {
      expect(QueryParser.evaluate('-cat:Dining', item), isTrue);
      expect(QueryParser.evaluate('-cat:Groceries', item), isFalse);
    });

    test('boolean AND and OR matching', () {
      expect(QueryParser.evaluate('cat:Groceries && amount:>50', item), isTrue);
      expect(QueryParser.evaluate('cat:Groceries && amount:<50', item), isFalse);
      expect(QueryParser.evaluate('cat:Dining || acc:Chase', item), isTrue);
      expect(QueryParser.evaluate('cat:Dining || acc:Cash', item), isFalse);
    });

    test('tag matching', () {
      expect(QueryParser.evaluate('tag:family', item), isTrue);
      expect(QueryParser.evaluate('tag:vacation', item), isFalse);
    });
  });
}
