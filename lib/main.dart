import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/budgets/presentation/screens/budgets_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/transactions/presentation/screens/add_transaction_sheet.dart';

import 'features/subscriptions/data/subscription_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: LuminaExpenseApp(),
    ),
  );
}

class LuminaExpenseApp extends ConsumerWidget {
  const LuminaExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    ThemeData activeDarkTheme = AppTheme.darkTheme;
    if (themeMode == AppThemeMode.amoled) {
      activeDarkTheme = AppTheme.amoledTheme;
    }

    ThemeMode flutterThemeMode;
    switch (themeMode) {
      case AppThemeMode.light:
        flutterThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        flutterThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        flutterThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: 'Lumina Expense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: activeDarkTheme,
      themeMode: flutterThemeMode,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AnalyticsScreen(),
    BudgetsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Catch-up on any past-due subscriptions with auto-log enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionRepositoryProvider).processAutoLogCatchUp();
    });
  }

  void _openAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(initialType: 'expense'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransaction(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            selectedIcon: Icon(Icons.insert_chart_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes_rounded),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
