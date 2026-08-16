import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/providers/database_provider.dart';
import 'package:lumina_expense/main.dart';

void main() {
  testWidgets('App starts and renders dashboard with in-memory database', (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const LuminaExpenseApp(),
      ),
    );

    // Pump initial frame and settle timers
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lumina Expense'), findsOneWidget);
    expect(find.text('Total Net Worth'), findsOneWidget);

    await testDb.close();
  });
}
