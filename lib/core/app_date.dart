import 'package:intl/intl.dart';

/// Shared date/time formatting helpers so every screen renders dates the same way.
class AppDate {
  const AppDate._();

  static final DateFormat _day = DateFormat('MMM d, yyyy');
  static final DateFormat _dayShort = DateFormat('MMM d');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _dayAndTime = DateFormat('MMM d, yyyy • HH:mm');
  static final DateFormat _weekday = DateFormat('EEE');

  static DateTime fromMillis(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis);

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfWeek(DateTime d) =>
      dayOnly(d).subtract(Duration(days: d.weekday - 1));

  static String formatDate(DateTime d) => _day.format(d);

  static String formatShortDate(DateTime d) => _dayShort.format(d);

  static String formatTime(DateTime d) => _time.format(d);

  static String formatDateTime(DateTime d) => _dayAndTime.format(d);

  static String formatWeekday(DateTime d) => _weekday.format(d);

  /// Human friendly due label: "Today 14:00", "Tomorrow 09:00", "3 days overdue".
  static String dueLabel(DateTime due, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final days = dayOnly(due).difference(dayOnly(reference)).inDays;

    if (days == 0) return 'Today • ${formatTime(due)}';
    if (days == 1) return 'Tomorrow • ${formatTime(due)}';
    if (days == -1) return 'Yesterday • ${formatTime(due)}';
    if (days < -1) return '${-days} days ago • ${formatShortDate(due)}';
    if (days < 7) return 'In $days days • ${formatWeekday(due)} ${formatTime(due)}';
    return formatDateTime(due);
  }
}
