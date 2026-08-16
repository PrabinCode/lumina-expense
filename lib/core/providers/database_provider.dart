import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Global AppDatabase provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
