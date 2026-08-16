import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class SubscriptionWithDetails {
  final RecurringTransaction subscription;
  final Category category;
  final Account account;

  SubscriptionWithDetails({
    required this.subscription,
    required this.category,
    required this.account,
  });

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      subscription.nextDueDate.year,
      subscription.nextDueDate.month,
      subscription.nextDueDate.day,
    );
    return due.difference(today).inDays;
  }

  bool get isOverdue => daysUntilDue < 0;
  bool get isDueToday => daysUntilDue == 0;
  bool get isDueThisWeek => daysUntilDue >= 0 && daysUntilDue <= 7;

  double get monthlyNormalizedAmount {
    switch (subscription.frequency) {
      case 'daily':
        return (subscription.amount / subscription.interval) * 30.4375;
      case 'weekly':
        return (subscription.amount / subscription.interval) * 4.348;
      case 'yearly':
        return subscription.amount / (12 * subscription.interval);
      case 'monthly':
      default:
        return subscription.amount / subscription.interval;
    }
  }

  double get yearlyNormalizedAmount => monthlyNormalizedAmount * 12;
}

class SubscriptionsSummary {
  final double totalMonthlyBurn;
  final double totalYearlyBurn;
  final int activeCount;
  final int upcomingThisWeekCount;

  SubscriptionsSummary({
    required this.totalMonthlyBurn,
    required this.totalYearlyBurn,
    required this.activeCount,
    required this.upcomingThisWeekCount,
  });
}

class SubscriptionRepository {
  final AppDatabase _db;

  SubscriptionRepository(this._db);

  /// Watch all subscriptions joined with category and account
  Stream<List<SubscriptionWithDetails>> watchSubscriptions({bool? isActive}) {
    final cat = _db.categories;
    final acc = _db.accounts;
    final rec = _db.recurringTransactions;

    final query = _db.select(rec).join([
      innerJoin(cat, cat.id.equalsExp(rec.categoryId)),
      innerJoin(acc, acc.id.equalsExp(rec.accountId)),
    ]);

    if (isActive != null) {
      query.where(rec.isActive.equals(isActive));
    }

    query.orderBy([
      OrderingTerm(expression: rec.nextDueDate, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return SubscriptionWithDetails(
          subscription: r.readTable(rec),
          category: r.readTable(cat),
          account: r.readTable(acc),
        );
      }).toList();
    });
  }

  /// Watch summary of active subscriptions (monthly burn, run rate, upcoming)
  Stream<SubscriptionsSummary> watchSubscriptionsSummary() {
    return watchSubscriptions(isActive: true).map((subs) {
      double monthlyBurn = 0.0;
      int upcomingCount = 0;

      for (final s in subs) {
        monthlyBurn += s.monthlyNormalizedAmount;
        if (s.isDueThisWeek || s.isOverdue) {
          upcomingCount++;
        }
      }

      return SubscriptionsSummary(
        totalMonthlyBurn: monthlyBurn,
        totalYearlyBurn: monthlyBurn * 12,
        activeCount: subs.length,
        upcomingThisWeekCount: upcomingCount,
      );
    });
  }

  Future<void> createSubscription(RecurringTransactionsCompanion sub) {
    return _db.into(_db.recurringTransactions).insert(sub);
  }

  Future<bool> updateSubscription(RecurringTransactionsCompanion sub) {
    return _db.update(_db.recurringTransactions).replace(sub);
  }

  Future<int> deleteSubscription(String id) {
    return (_db.delete(_db.recurringTransactions)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> toggleSubscriptionActive(String id, bool isActive) {
    return (_db.update(_db.recurringTransactions)..where((tbl) => tbl.id.equals(id))).write(
      RecurringTransactionsCompanion(isActive: Value(isActive)),
    );
  }

  /// Advances nextDueDate according to frequency and interval
  DateTime calculateNextDueDate(DateTime currentDue, String frequency, int interval) {
    final safeInterval = interval < 1 ? 1 : interval;
    switch (frequency) {
      case 'daily':
        return currentDue.add(Duration(days: safeInterval));
      case 'weekly':
        return currentDue.add(Duration(days: 7 * safeInterval));
      case 'yearly':
        return DateTime(currentDue.year + safeInterval, currentDue.month, currentDue.day, currentDue.hour, currentDue.minute);
      case 'monthly':
      default:
        var newYear = currentDue.year;
        var newMonth = currentDue.month + safeInterval;
        while (newMonth > 12) {
          newYear++;
          newMonth -= 12;
        }
        // Handle end of month day clamping (e.g. Jan 31 -> Feb 28)
        final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        final newDay = currentDue.day > lastDayOfNewMonth ? lastDayOfNewMonth : currentDue.day;
        return DateTime(newYear, newMonth, newDay, currentDue.hour, currentDue.minute);
    }
  }

  /// Manually log payment for a subscription and advance its due date
  Future<void> logSubscriptionPayment(String id, {DateTime? paymentDate}) async {
    final sub = await (_db.select(_db.recurringTransactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (sub == null) return;

    final actualPaymentDate = paymentDate ?? DateTime.now();
    const uuid = Uuid();

    await _db.transaction(() async {
      // 1. Record transaction
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              title: '${sub.title} (Recurring)',
              amount: sub.amount,
              type: 'expense',
              categoryId: Value(sub.categoryId),
              accountId: sub.accountId,
              date: Value(actualPaymentDate),
              note: Value(sub.notes != null ? 'Recurring bill: ${sub.notes}' : 'Recurring subscription payment'),
            ),
          );

      // 2. Advance due date
      final nextDue = calculateNextDueDate(sub.nextDueDate, sub.frequency, sub.interval);
      await (_db.update(_db.recurringTransactions)..where((tbl) => tbl.id.equals(id))).write(
        RecurringTransactionsCompanion(nextDueDate: Value(nextDue)),
      );
    });
  }

  /// Catch up and automatically log due subscriptions with autoLog enabled
  Future<int> processAutoLogCatchUp() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final dueSubs = await (_db.select(_db.recurringTransactions)
          ..where((tbl) => tbl.isActive.equals(true) & tbl.autoLog.equals(true) & tbl.nextDueDate.isSmallerOrEqualValue(today)))
        .get();

    int loggedCount = 0;
    const uuid = Uuid();

    for (final sub in dueSubs) {
      var currentDue = sub.nextDueDate;
      while (currentDue.isBefore(today) || currentDue.isAtSameMomentAs(today)) {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: uuid.v4(),
                title: '${sub.title} (Auto-log)',
                amount: sub.amount,
                type: 'expense',
                categoryId: Value(sub.categoryId),
                accountId: sub.accountId,
                date: Value(currentDue),
                note: Value(sub.notes != null ? 'Auto-logged: ${sub.notes}' : 'Auto-logged subscription payment'),
              ),
            );
        loggedCount++;
        currentDue = calculateNextDueDate(currentDue, sub.frequency, sub.interval);
      }

      await (_db.update(_db.recurringTransactions)..where((tbl) => tbl.id.equals(sub.id))).write(
        RecurringTransactionsCompanion(nextDueDate: Value(currentDue)),
      );
    }

    return loggedCount;
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SubscriptionRepository(db);
});

final activeSubscriptionsStreamProvider = StreamProvider<List<SubscriptionWithDetails>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchSubscriptions(isActive: true);
});

final allSubscriptionsStreamProvider = StreamProvider<List<SubscriptionWithDetails>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchSubscriptions();
});

final subscriptionsSummaryStreamProvider = StreamProvider<SubscriptionsSummary>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchSubscriptionsSummary();
});
