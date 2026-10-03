import 'package:intl/intl.dart';
import '../providers/app_preferences_provider.dart';

class AppDateFormatter {
  static AppDateFormat activeDateFormat = AppDateFormat.dmySlash;
  static AppTimeFormat activeTimeFormat = AppTimeFormat.twelveHour;

  /// Formats date according to active or specified AppDateFormat
  static String formatDate(DateTime date, {AppDateFormat? format}) {
    final active = format ?? activeDateFormat;
    return DateFormat(active.pattern).format(date);
  }

  /// Formats time according to active or specified AppTimeFormat
  static String formatTime(DateTime date, {AppTimeFormat? format}) {
    final active = format ?? activeTimeFormat;
    return DateFormat(active.pattern).format(date);
  }

  /// Formats both date and time (e.g. "02/10/2026 • 08:30 PM")
  static String formatDateTime(DateTime date, {AppDateFormat? dateFormat, AppTimeFormat? timeFormat}) {
    final d = formatDate(date, format: dateFormat);
    final t = formatTime(date, format: timeFormat);
    return '$d • $t';
  }

  /// Returns friendly relative date (e.g. "Today", "Yesterday", or formatted date)
  static String formatRelativeOrDate(DateTime date, {AppDateFormat? format}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) {
      return 'Today';
    } else if (check == yesterday) {
      return 'Yesterday';
    }
    return formatDate(date, format: format);
  }

  /// Short month and day format for charts/summaries (e.g. "Oct 2")
  static String formatMonthDay(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  /// Full month and year (e.g. "October 2026")
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}
