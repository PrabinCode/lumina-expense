import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/providers/database_provider.dart';
import 'package:lumina_expense/core/theme/app_theme.dart';
import 'package:lumina_expense/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:lumina_expense/features/backup/services/backup_restore_service.dart';
import 'package:lumina_expense/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:lumina_expense/features/debts/presentation/screens/debts_screen.dart';
import 'package:lumina_expense/features/goals/presentation/screens/goals_screen.dart';
import 'package:lumina_expense/features/settings/presentation/screens/settings_screen.dart';
import 'package:lumina_expense/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture authentic app screenshots for web showcase and Play Store', (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Lumina Expense',
      packageName: 'com.prabincode.luminaexpense',
      version: '1.8.0',
      buildNumber: '9',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({
      'is_onboarded': true,
      'theme_mode': 'dark',
    });

    final testDb = AppDatabase(NativeDatabase.memory());
    final backupService = BackupRestoreService(testDb);
    await backupService.seedDemoData();

    // Set phone viewport (1080x2400 @ 2.625 density)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    final targetDirs = [
      Directory('playstore_assets/screenshots'),
      Directory('../PrabinCode/portfolio/public/images/lumina'),
    ];
    for (final d in targetDirs) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }

    Future<void> captureScreen(Widget screenWidget, String filename) async {
      final globalKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: RepaintBoundary(
              key: globalKey,
              child: screenWidget,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.binding.runAsync(() async {
        final boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.625);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            for (final d in targetDirs) {
              final file = File('${d.path}/$filename.png');
              file.writeAsBytesSync(pngBytes);
              // ignore: avoid_print
              print('Saved authentic screenshot: ${file.path} (${pngBytes.length} bytes)');
            }
          }
        }
      });
    }

    // 1. Dashboard
    await captureScreen(const LuminaExpenseApp(), 'screenshot_dashboard');

    // 2. Analytics (August 2026 with full breakdown & chart)
    await captureScreen(Scaffold(body: AnalyticsScreen(initialMonth: DateTime(2026, 8, 1))), 'screenshot_analytics');

    // 3. Budgets
    await captureScreen(const Scaffold(body: BudgetsScreen()), 'screenshot_budgets');

    // 4. Goals & Sinking Funds
    await captureScreen(const GoalsScreen(), 'screenshot_goals');

    // 5. Debts & Lending
    await captureScreen(const DebtsScreen(), 'screenshot_debts');

    // 6. Settings & Diagnostics
    await captureScreen(const Scaffold(body: SettingsScreen()), 'screenshot_settings');

    await testDb.close();
  });
}
