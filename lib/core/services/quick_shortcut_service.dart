import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/health/presentation/screens/financial_health_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_sheet.dart';

class QuickShortcutService {
  static const _channel = MethodChannel('com.prabincode.luminaexpense/shortcuts');
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAction') {
        final uri = call.arguments as String?;
        if (uri != null) {
          handleActionUri(uri);
        }
      }
    });

    // Check for cold-start launch shortcut
    _channel.invokeMethod<String>('getInitialAction').then((uri) {
      if (uri != null && uri.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            handleActionUri(uri);
          });
        });
      }
    }).catchError((_) {});
  }

  static void handleActionUri(String uri) {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    if (uri.contains('add_expense')) {
      showModalBottomSheet(
        context: navContext,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddTransactionSheet(initialType: 'expense'),
      );
    } else if (uri.contains('add_income')) {
      showModalBottomSheet(
        context: navContext,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddTransactionSheet(initialType: 'income'),
      );
    } else if (uri.contains('health_score') || uri.contains('health')) {
      Navigator.of(navContext).push(
        MaterialPageRoute(builder: (_) => const FinancialHealthScreen()),
      );
    }
  }
}
