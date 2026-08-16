import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/app_lock/data/app_lock_service.dart';
import 'features/app_lock/presentation/screens/app_lock_screen.dart';
import 'features/app_lock/presentation/widgets/privacy_shield_widget.dart';
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
      home: const _AppLockGate(),
    );
  }
}

/// Gate widget that shows lock screen or main content based on lock state.
/// Also handles privacy shield and app lifecycle transitions.
class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate();

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate>
    with WidgetsBindingObserver {
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lockService = ref.read(appLockServiceProvider);

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App going to background
        lockService.onAppPaused();
        if (lockService.privacyShieldEnabled && lockService.isEnabled) {
          setState(() => _isInBackground = true);
        }
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground
        setState(() => _isInBackground = false);
        lockService.onAppResumed();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockService = ref.watch(appLockServiceProvider);

    // Show loading while lock service initializes
    if (!lockService.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show lock screen if locked
    if (lockService.isEnabled && lockService.isLocked) {
      return const AppLockScreen();
    }

    // Show main content with optional privacy shield overlay
    return PrivacyShieldWidget(
      isActive: _isInBackground,
      child: const MainNavigationShell(),
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
