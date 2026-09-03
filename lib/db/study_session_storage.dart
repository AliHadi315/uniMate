import 'package:unimate/core/app_date.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

/// Records one completed focus-timer block.
Future<int> insertStudySession({
  required int userId,
  int? courseId,
  required DateTime startedAt,
  required int minutes,
}) async {
  final db = await DatabaseProvider.getDatabase();
  return db.insert(DbTables.studySessions, {
    'userId': userId,
    'courseId': courseId,
    'startedAtMillis': startedAt.millisecondsSinceEpoch,
    'minutes': minutes,
  });
}

/// Focused minutes per day for the last [days] days, oldest first —
/// mirrors [completionsPerDay] for the statistics chart.
Future<List<int>> studyMinutesPerDay(int userId, {int days = 7}) async {
  final db = await DatabaseProvider.getDatabase();
  final start = AppDate.dayOnly(
    DateTime.now().subtract(Duration(days: days - 1)),
  );

  final rows = await db.query(
    DbTables.studySessions,
    columns: ['startedAtMillis', 'minutes'],
    where: 'userId = ? AND startedAtMillis >= ?',
    whereArgs: [userId, start.millisecondsSinceEpoch],
  );

  final buckets = List<int>.filled(days, 0);
  for (final row in rows) {
    final day = AppDate.dayOnly(
      DateTime.fromMillisecondsSinceEpoch(row['startedAtMillis'] as int),
    );
    final index = day.difference(start).inDays;
    if (index >= 0 && index < days) {
      buckets[index] += row['minutes'] as int;
    }
  }
  return buckets;
}

/// Total focused minutes in the last [days] days grouped by course code.
/// Sessions without a course (or whose course was deleted) fall under
/// 'General'. Archived courses still count — the time was spent.
Future<Map<String, int>> studyMinutesByCourse(
  int userId, {
  int days = 7,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final start = AppDate.dayOnly(
    DateTime.now().subtract(Duration(days: days - 1)),
  );

  final rows = await db.rawQuery(
    'SELECT c.code AS code, SUM(s.minutes) AS total '
    'FROM ${DbTables.studySessions} s '
    'LEFT JOIN ${DbTables.courses} c ON c.id = s.courseId '
    'WHERE s.userId = ? AND s.startedAtMillis >= ? '
    'GROUP BY c.code ORDER BY total DESC',
    [userId, start.millisecondsSinceEpoch],
  );

  return {
    for (final row in rows)
      ((row['code'] as String?) ?? 'General'): (row['total'] as int?) ?? 0,
  };
}
