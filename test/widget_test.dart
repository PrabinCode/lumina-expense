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

  testWidgets('App shows onboarding slider on first launch and navigates through slides', (WidgetTester tester) async {
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

    // Slide 1: Privacy
    expect(find.text('100% PRIVATE & OFFLINE'), findsOneWidget);
    expect(find.text('Total Privacy,\nZero Cloud Tracking'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Tap Next -> Slide 2: Smart Budgeting
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('EFFORTLESS MANAGEMENT'), findsOneWidget);
    expect(find.text('Smart Tracking\n& Category Budgets'), findsOneWidget);

    // Tap Next -> Slide 3: Analytics
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('DEEP INSIGHTS & REPORTS'), findsOneWidget);
    expect(find.text('Insightful Analytics\n& Cash Flow Trends'), findsOneWidget);

    // Tap Next -> Slide 4: Setup & Personalize
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Personalize Your Lumina'), findsOneWidget);
    expect(find.text('Default Currency'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Complete Onboarding
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify main app dashboard appears
    expect(find.text('Total Net Worth'), findsOneWidget);

    await testDb.close();
  });
}
