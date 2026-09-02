import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/theme/app_colors.dart';
import 'package:lumina_expense/features/transactions/presentation/widgets/num_keypad.dart';

void main() {
  testWidgets('NumKeypad renders all keys and responds to rapid taps and long press', (WidgetTester tester) async {
    final pressedKeys = <String>[];
    var deleteCount = 0;
    var clearCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumKeypad(
            accentColor: AppColors.expense,
            onKeyPressed: (key) => pressedKeys.add(key),
            onDelete: () => deleteCount++,
            onClear: () => clearCount++,
          ),
        ),
      ),
    );

    // Verify all keys are rendered
    for (final digit in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(find.text('.'), findsOneWidget);
    expect(find.byIcon(Icons.backspace_rounded), findsOneWidget);

    // Test quick tap on '7'
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(pressedKeys, contains('7'));

    // Settle minimum hold animation
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Test tap on '2'
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(pressedKeys, contains('2'));
    await tester.pumpAndSettle();

    // Test backspace tap
    await tester.tap(find.byIcon(Icons.backspace_rounded));
    await tester.pump();
    expect(deleteCount, equals(1));
    await tester.pumpAndSettle();

    // Test backspace long press
    await tester.longPress(find.byIcon(Icons.backspace_rounded));
    await tester.pumpAndSettle();
    expect(clearCount, equals(1));
  });

  testWidgets('NumKeypad works with different mode accent colors', (WidgetTester tester) async {
    for (final color in [AppColors.expense, AppColors.income, AppColors.transfer]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NumKeypad(
              accentColor: color,
              onKeyPressed: (_) {},
              onDelete: () {},
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NumKeypad), findsOneWidget);
    }
  });
}
