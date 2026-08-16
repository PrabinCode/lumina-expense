import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/providers/database_provider.dart';
import 'package:lumina_expense/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and renders dashboard when onboarded', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'is_onboarded': true});
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const LuminaExpenseApp(),
      ),
    );

    // Settle async providers and animations
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Lumina Expense'), findsWidgets);
    expect(find.text('Total Net Worth'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('App shows onboarding screen on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'is_onboarded': false});
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const LuminaExpenseApp(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Lumina Expense'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await testDb.close();
  });
}
