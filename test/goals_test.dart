import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/goals/data/goal_repository.dart';

void main() {
  late AppDatabase db;
  late GoalRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = GoalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates a goal and verifies properties', () async {
    const goalId = 'goal-1';
    await repository.createGoal(
      GoalsCompanion.insert(
        id: goalId,
        name: 'New Laptop',
        targetAmount: 1500.0,
        currentAmount: const drift.Value(500.0),
        iconName: const drift.Value('laptop'),
        colorValue: const drift.Value(0xFF3B82F6),
      ),
    );

    final goals = await repository.watchGoals().first;
    expect(goals.length, 1);
    expect(goals.first.name, 'New Laptop');
    expect(goals.first.targetAmount, 1500.0);
    expect(goals.first.currentAmount, 500.0);
    expect(goals.first.isCompleted, false);
  });

  test('Depositing to a goal updates balance and auto-completes when target reached', () async {
    const goalId = 'goal-vacation';
    await repository.createGoal(
      GoalsCompanion.insert(
        id: goalId,
        name: 'Japan Vacation',
        targetAmount: 2000.0,
        currentAmount: const drift.Value(1000.0),
      ),
    );

    // Deposit 500 -> total 1500, not completed
    await repository.depositToGoal(goalId, 500.0);
    var goals = await repository.watchGoals().first;
    expect(goals.first.currentAmount, 1500.0);
    expect(goals.first.isCompleted, false);

    // Deposit 600 -> total 2100, completed
    await repository.depositToGoal(goalId, 600.0);
    goals = await repository.watchGoals().first;
    expect(goals.first.currentAmount, 2100.0);
    expect(goals.first.isCompleted, true);
  });

  test('Withdrawing from a goal decreases balance', () async {
    const goalId = 'goal-emergency';
    await repository.createGoal(
      GoalsCompanion.insert(
        id: goalId,
        name: 'Emergency Fund',
        targetAmount: 5000.0,
        currentAmount: const drift.Value(3000.0),
      ),
    );

    await repository.withdrawFromGoal(goalId, 1000.0);
    final goals = await repository.watchGoals().first;
    expect(goals.first.currentAmount, 2000.0);
  });

  test('Goals summary computes total target, saved, and progress correctly', () async {
    await repository.createGoal(
      GoalsCompanion.insert(
        id: 'g1',
        name: 'Goal 1',
        targetAmount: 1000.0,
        currentAmount: const drift.Value(500.0),
      ),
    );

    await repository.createGoal(
      GoalsCompanion.insert(
        id: 'g2',
        name: 'Goal 2',
        targetAmount: 3000.0,
        currentAmount: const drift.Value(3000.0),
        isCompleted: const drift.Value(true),
      ),
    );

    final summary = await repository.watchGoalsSummary().first;
    expect(summary.totalGoals, 2);
    expect(summary.completedGoals, 1);
    expect(summary.totalTarget, 4000.0);
    expect(summary.totalSaved, 3500.0);
    expect(summary.overallProgress, closeTo(3500.0 / 4000.0, 0.001));
  });

  test('Deleting a goal removes it completely', () async {
    const goalId = 'goal-to-delete';
    await repository.createGoal(
      GoalsCompanion.insert(
        id: goalId,
        name: 'Temporary Goal',
        targetAmount: 100.0,
      ),
    );

    var goals = await repository.watchGoals().first;
    expect(goals.length, 1);

    await repository.deleteGoal(goalId);
    goals = await repository.watchGoals().first;
    expect(goals.isEmpty, true);
  });
}
