import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19);
    final prefix = level.name.toUpperCase().padRight(7);
    if (error != null) {
      return '[$timeStr] $prefix $message | Error: $error';
    }
    return '[$timeStr] $prefix $message';
  }
}

class AppLogService {
  AppLogService._internal();
  static final AppLogService instance = AppLogService._internal();

  static const int _maxLogs = 100;
  final Queue<LogEntry> _logs = Queue<LogEntry>();

  static void initialize() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      instance.logError(
        details.summary.toString(),
        error: details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
      );
      if (originalOnError != null) {
        originalOnError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      instance.logError(
        'Unhandled Platform Exception',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
      return true;
    };

    instance.logInfo('Lumina Expense initialized (v1.1.0+2)');
  }

  void logInfo(String message) {
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      message: message,
    ));
  }

  void logWarn(String message) {
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      message: message,
    ));
  }

  void logError(String message, {String? error, String? stackTrace}) {
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void _addLog(LogEntry entry) {
    if (_logs.length >= _maxLogs) {
      _logs.removeFirst();
    }
    _logs.addLast(entry);
    debugPrint(entry.toString());
  }

  List<LogEntry> get logs => List.unmodifiable(_logs);

  String getDiagnosticReport({
    int? accountsCount,
    int? transactionsCount,
    int? budgetsCount,
    int? debtsCount,
    int? goalsCount,
    int? subscriptionsCount,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('  LUMINA EXPENSE TRACKER - DIAGNOSTIC REPORT');
    buffer.writeln('  Generated: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('========================================');
    buffer.writeln();
    buffer.writeln('--- APP & DEVICE INFO ---');
    buffer.writeln('App Version: v1.1.0 (Build 2)');
    buffer.writeln('Package: com.prabincode.luminaexpense');
    buffer.writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('Locale: ${Platform.localeName}');
    buffer.writeln('Database Schema: v4');
    buffer.writeln();

    buffer.writeln('--- ANONYMIZED STATS (Privacy Compliant) ---');
    if (accountsCount != null) buffer.writeln('Total Accounts: $accountsCount');
    if (transactionsCount != null) buffer.writeln('Total Transactions: $transactionsCount');
    if (budgetsCount != null) buffer.writeln('Active Budgets: $budgetsCount');
    if (debtsCount != null) buffer.writeln('Tracked Debts: $debtsCount');
    if (goalsCount != null) buffer.writeln('Savings Goals: $goalsCount');
    if (subscriptionsCount != null) buffer.writeln('Subscriptions: $subscriptionsCount');
    buffer.writeln();

    buffer.writeln('--- RECENT SYSTEM LOGS (${_logs.length} entries) ---');
    if (_logs.isEmpty) {
      buffer.writeln('No error logs recorded.');
    } else {
      for (final log in _logs) {
        buffer.writeln(log.toString());
        if (log.stackTrace != null && log.stackTrace!.isNotEmpty) {
          final lines = log.stackTrace!.split('\n').take(4).join('\n');
          buffer.writeln('  Stack: $lines');
        }
      }
    }
    buffer.writeln();
    buffer.writeln('========================================');
    return buffer.toString();
  }

  Future<File> exportLogFile({
    int? accountsCount,
    int? transactionsCount,
    int? budgetsCount,
    int? debtsCount,
    int? goalsCount,
    int? subscriptionsCount,
  }) async {
    final report = getDiagnosticReport(
      accountsCount: accountsCount,
      transactionsCount: transactionsCount,
      budgetsCount: budgetsCount,
      debtsCount: debtsCount,
      goalsCount: goalsCount,
      subscriptionsCount: subscriptionsCount,
    );
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/lumina_diagnostics_$timestamp.txt');
    await file.writeAsString(report);
    return file;
  }
}
