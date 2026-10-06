import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/default_data.dart';
import '../../../core/providers/database_provider.dart';

class ProfileRepository {
  final AppDatabase _db;

  ProfileRepository(this._db);

  Stream<List<UserProfile>> watchAllProfiles() {
    return (_db.select(_db.userProfiles)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<UserProfile>> getAllProfiles() {
    return (_db.select(_db.userProfiles)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<UserProfile?> getProfileById(String id) {
    return (_db.select(_db.userProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<UserProfile?> getDefaultProfile() async {
    final profile = await (_db.select(_db.userProfiles)..where((t) => t.isDefault.equals(true))).getSingleOrNull();
    if (profile != null) return profile;
    final all = await getAllProfiles();
    return all.isNotEmpty ? all.first : null;
  }

  Future<UserProfile> createProfile({
    required String name,
    String? email,
    String icon = 'person',
    int color = 0xFF10B981,
    String currency = 'USD',
    bool isDefault = false,
    bool seedDefaults = true,
  }) async {
    const uuid = Uuid();
    final profileId = 'prof_${uuid.v4().substring(0, 8)}';

    final companion = UserProfilesCompanion.insert(
      id: profileId,
      name: name.trim(),
      email: Value(email != null && email.trim().isNotEmpty ? email.trim() : null),
      icon: Value(icon),
      color: Value(color),
      currency: Value(currency),
      isDefault: Value(isDefault),
      createdAt: Value(DateTime.now()),
    );

    await _db.into(_db.userProfiles).insert(companion);

    if (seedDefaults) {
      // Seed default accounts for this profile
      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_${profileId}_cash',
          profileId: Value(profileId),
          name: 'Cash Wallet',
          type: 'cash',
          currency: Value(currency),
          icon: const Value('payments'),
          color: const Value(0xFF4CAF50),
          initialBalance: const Value(0.0),
        ),
      );
      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_${profileId}_bank',
          profileId: Value(profileId),
          name: 'Bank Account',
          type: 'bank',
          currency: Value(currency),
          icon: const Value('account_balance'),
          color: const Value(0xFF2196F3),
          initialBalance: const Value(0.0),
        ),
      );

      // Seed default categories for this profile
      for (final cat in DefaultData.categories) {
        await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat_${profileId}_${cat.id}',
            profileId: Value(profileId),
            name: cat.name,
            type: cat.type,
            icon: Value(cat.icon),
            color: Value(cat.color),
            isDefault: const Value(true),
          ),
        );
      }
    }

    return (await getProfileById(profileId))!;
  }

  Future<bool> updateProfile(UserProfilesCompanion profile) {
    return _db.update(_db.userProfiles).replace(profile);
  }

  Future<int> deleteProfile(String profileId) async {
    final profiles = await getAllProfiles();
    if (profiles.length <= 1) {
      throw Exception('Cannot delete the only remaining profile.');
    }

    return _db.transaction(() async {
      // Delete soft-deleted items for this profile
      await (_db.delete(_db.deletedItems)..where((t) => t.profileId.equals(profileId))).go();

      // Delete recurring transactions
      await (_db.delete(_db.recurringTransactions)..where((t) => t.profileId.equals(profileId))).go();

      // Delete debts & repayments
      final debts = await (_db.select(_db.debts)..where((t) => t.profileId.equals(profileId))).get();
      for (final d in debts) {
        await (_db.delete(_db.debtRepayments)..where((t) => t.debtId.equals(d.id))).go();
      }
      await (_db.delete(_db.debts)..where((t) => t.profileId.equals(profileId))).go();

      // Delete goals & transactions
      final goals = await (_db.select(_db.goals)..where((t) => t.profileId.equals(profileId))).get();
      for (final g in goals) {
        await (_db.delete(_db.goalTransactions)..where((t) => t.goalId.equals(g.id))).go();
      }
      await (_db.delete(_db.goals)..where((t) => t.profileId.equals(profileId))).go();

      // Delete budgets
      await (_db.delete(_db.budgets)..where((t) => t.profileId.equals(profileId))).go();

      // Delete transactions & splits
      final txs = await (_db.select(_db.transactions)..where((t) => t.profileId.equals(profileId))).get();
      for (final tx in txs) {
        await (_db.delete(_db.transactionSplits)..where((t) => t.transactionId.equals(tx.id))).go();
      }
      await (_db.delete(_db.transactions)..where((t) => t.profileId.equals(profileId))).go();

      // Delete accounts & categories
      await (_db.delete(_db.accounts)..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(_db.categories)..where((t) => t.profileId.equals(profileId))).go();

      // Finally delete the profile
      return (_db.delete(_db.userProfiles)..where((t) => t.id.equals(profileId))).go();
    });
  }

  Future<int> getTransactionCountForProfile(String profileId) async {
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id.count()])
      ..where(_db.transactions.profileId.equals(profileId));
    return await query.map((row) => row.read(_db.transactions.id.count()) ?? 0).getSingle();
  }

  Future<int> getAccountCountForProfile(String profileId) async {
    final query = _db.selectOnly(_db.accounts)
      ..addColumns([_db.accounts.id.count()])
      ..where(_db.accounts.profileId.equals(profileId));
    return await query.map((row) => row.read(_db.accounts.id.count()) ?? 0).getSingle();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProfileRepository(db);
});
