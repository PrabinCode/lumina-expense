import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class GoalsSummary {
  final double totalTarget;
  final double totalSaved;
  final int totalGoals;
  final int completedGoals;

  GoalsSummary({
    required this.totalTarget,
    required this.totalSaved,
    required this.totalGoals,
    required this.completedGoals,
  });

  double get overallProgress => totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
}

class GoalRepository {
  final AppDatabase _db;

  GoalRepository(this._db);

  Stream<List<Goal>> watchGoals({bool? isCompleted}) {
    final query = _db.select(_db.goals);
    if (isCompleted != null) {
      query.where((tbl) => tbl.isCompleted.equals(isCompleted));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<void> createGoal(GoalsCompanion goal) {
    return _db.into(_db.goals).insert(goal);
  }

  Future<bool> updateGoal(GoalsCompanion goal) {
    return _db.update(_db.goals).replace(goal);
  }

  Future<int> deleteGoal(String id) {
    return (_db.delete(_db.goals)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> depositToGoal(String id, double amount) async {
    final existing = await (_db.select(_db.goals)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (existing == null) return;

    final newCurrent = existing.currentAmount + amount;
    final isCompleted = newCurrent >= existing.targetAmount;

    await (_db.update(_db.goals)..where((tbl) => tbl.id.equals(id))).write(
      GoalsCompanion(
        currentAmount: Value(newCurrent),
        isCompleted: Value(isCompleted),
      ),
    );
  }

  Future<void> withdrawFromGoal(String id, double amount) async {
    final existing = await (_db.select(_db.goals)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (existing == null) return;

    final newCurrent = (existing.currentAmount - amount).clamp(0.0, double.infinity);
    final isCompleted = newCurrent >= existing.targetAmount;

    await (_db.update(_db.goals)..where((tbl) => tbl.id.equals(id))).write(
      GoalsCompanion(
        currentAmount: Value(newCurrent),
        isCompleted: Value(isCompleted),
      ),
    );
  }

  Stream<GoalsSummary> watchGoalsSummary() {
    return _db.select(_db.goals).watch().map((goals) {
      double target = 0.0;
      double saved = 0.0;
      int completed = 0;

      for (final g in goals) {
        target += g.targetAmount;
        saved += g.currentAmount;
        if (g.isCompleted) {
          completed++;
        }
      }

      return GoalsSummary(
        totalTarget: target,
        totalSaved: saved,
        totalGoals: goals.length,
        completedGoals: completed,
      );
    });
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepository(db);
});

final goalsStreamProvider = StreamProvider.family<List<Goal>, bool?>((ref, isCompleted) {
  return ref.watch(goalRepositoryProvider).watchGoals(isCompleted: isCompleted);
});

final goalsSummaryStreamProvider = StreamProvider<GoalsSummary>((ref) {
  return ref.watch(goalRepositoryProvider).watchGoalsSummary();
});
