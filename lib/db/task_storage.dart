import 'package:unimate/core/app_date.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

import '../models/course.dart';
import '../models/task.dart';

/// A task together with the course it belongs to, used by cross-course views.
class TaskWithCourse {
  final Task task;
  final Course course;

  const TaskWithCourse({required this.task, required this.course});
}

// Every Task column must appear here: a missing one silently reads back as
// null through the joined views, which once cost recurring tasks their
// recurrence when completed from the agenda.
const _taskColumns =
    't.id AS id, t.courseId AS courseId, t.title AS title, t.type AS type, '
    't.dueDateMillis AS dueDateMillis, t.priority AS priority, '
    't.isCompleted AS isCompleted, t.notes AS notes, '
    't.reminderMinutesBefore AS reminderMinutesBefore, '
    't.completedAtMillis AS completedAtMillis, '
    't.recurrenceDays AS recurrenceDays, t.attachmentPath AS attachmentPath';

const _courseColumns =
    'c.id AS c_id, c.userId AS c_userId, c.name AS c_name, c.code AS c_code, '
    'c.instructor AS c_instructor, c.semester AS c_semester, '
    'c.colorValue AS c_colorValue, c.archived AS c_archived';

TaskWithCourse _joinedRow(Map<String, Object?> row) {
  return TaskWithCourse(
    task: Task.fromMap(row),
    course: Course.fromMap({
      'id': row['c_id'],
      'userId': row['c_userId'],
      'name': row['c_name'],
      'code': row['c_code'],
      'instructor': row['c_instructor'],
      'semester': row['c_semester'],
      'colorValue': row['c_colorValue'],
      'archived': row['c_archived'],
    }),
  );
}

Future<int> insertTask(Task task) async {
  final db = await DatabaseProvider.getDatabase();
  final map = task.toMap()..remove('id');
  return db.insert(DbTables.tasks, map);
}

Future<Task?> loadTaskById(int taskId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.tasks,
    where: 'id = ?',
    whereArgs: [taskId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return Task.fromMap(rows.first);
}

Future<List<Task>> loadTasksByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.tasks,
    where: 'courseId = ?',
    whereArgs: [courseId],
    orderBy: 'isCompleted ASC, dueDateMillis ASC',
  );
  return rows.map(Task.fromMap).toList();
}

/// Every task belonging to [userId], joined with its course.
Future<List<TaskWithCourse>> loadAllTasks(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_taskColumns, $_courseColumns '
    'FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 '
    'ORDER BY t.isCompleted ASC, t.dueDateMillis ASC',
    [userId],
  );
  return rows.map(_joinedRow).toList();
}

Future<int> updateTask(Task task) async {
  final db = await DatabaseProvider.getDatabase();
  final map = task.toMap()..remove('id');
  return db.update(DbTables.tasks, map, where: 'id = ?', whereArgs: [task.id]);
}

Future<int> deleteTaskById(int taskId) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(DbTables.tasks, where: 'id = ?', whereArgs: [taskId]);
}

Future<int> setTaskCompleted(int taskId, bool completed) async {
  final db = await DatabaseProvider.getDatabase();
  return db.update(
    DbTables.tasks,
    {
      'isCompleted': completed ? 1 : 0,
      'completedAtMillis': completed
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    },
    where: 'id = ?',
    whereArgs: [taskId],
  );
}

Future<int> _countTasks(
  int userId, {
  String? extraWhere,
  List<Object?> extraArgs = const [],
}) async {
  final db = await DatabaseProvider.getDatabase();
  final where = extraWhere == null ? '' : ' AND $extraWhere';
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS total FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0$where',
    [userId, ...extraArgs],
  );
  return (rows.first['total'] as int?) ?? 0;
}

Future<int> countPendingTasksByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS total FROM ${DbTables.tasks} '
    'WHERE courseId = ? AND isCompleted = 0',
    [courseId],
  );
  return (rows.first['total'] as int?) ?? 0;
}

Future<int> countAllTasks(int userId) => _countTasks(userId);

Future<int> countCompletedTasks(int userId) =>
    _countTasks(userId, extraWhere: 't.isCompleted = 1');

/// Not completed and not yet past its due date.
Future<int> countPendingTasks(int userId) => _countTasks(
  userId,
  extraWhere: 't.isCompleted = 0 AND t.dueDateMillis >= ?',
  extraArgs: [DateTime.now().millisecondsSinceEpoch],
);

Future<int> countOverdueTasks(int userId) => _countTasks(
  userId,
  extraWhere: 't.isCompleted = 0 AND t.dueDateMillis < ?',
  extraArgs: [DateTime.now().millisecondsSinceEpoch],
);

/// Tasks due today that are still open.
Future<int> countDueTodayTasks(int userId) {
  final start = AppDate.dayOnly(DateTime.now());
  final end = start.add(const Duration(days: 1));
  return _countTasks(
    userId,
    extraWhere:
        't.isCompleted = 0 AND t.dueDateMillis >= ? AND t.dueDateMillis < ?',
    extraArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
  );
}

Future<List<TaskWithCourse>> loadUpcomingTasks(
  int userId, {
  int limit = 5,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_taskColumns, $_courseColumns '
    'FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 0 AND t.dueDateMillis >= ? '
    'ORDER BY t.dueDateMillis ASC LIMIT ?',
    [userId, DateTime.now().millisecondsSinceEpoch, limit],
  );
  return rows.map(_joinedRow).toList();
}

/// Open tasks whose due date has already passed, most recent first.
Future<List<TaskWithCourse>> loadOverdueTasks(
  int userId, {
  int limit = 5,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_taskColumns, $_courseColumns '
    'FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 0 AND t.dueDateMillis < ? '
    'ORDER BY t.dueDateMillis DESC LIMIT ?',
    [userId, DateTime.now().millisecondsSinceEpoch, limit],
  );
  return rows.map(_joinedRow).toList();
}

/// Open tasks that carry a reminder — used to restore scheduled
/// notifications after the app restarts.
Future<List<TaskWithCourse>> loadTasksWithReminders(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_taskColumns, $_courseColumns '
    'FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 0 '
    'AND t.reminderMinutesBefore IS NOT NULL',
    [userId],
  );
  return rows.map(_joinedRow).toList();
}

/// How many tasks were completed on each of the last [days] days, oldest
/// first. Drives the weekly activity chart.
Future<List<int>> completionsPerDay(int userId, {int days = 7}) async {
  final db = await DatabaseProvider.getDatabase();
  final start = AppDate.dayOnly(
    DateTime.now().subtract(Duration(days: days - 1)),
  );

  final rows = await db.rawQuery(
    'SELECT t.completedAtMillis AS completedAt FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 1 AND t.completedAtMillis >= ?',
    [userId, start.millisecondsSinceEpoch],
  );

  final buckets = List<int>.filled(days, 0);
  for (final row in rows) {
    final millis = row['completedAt'] as int?;
    if (millis == null) continue;
    final day = AppDate.dayOnly(DateTime.fromMillisecondsSinceEpoch(millis));
    final index = day.difference(start).inDays;
    if (index >= 0 && index < days) buckets[index]++;
  }
  return buckets;
}

/// Open-task counts grouped by priority.
Future<Map<String, int>> pendingByPriority(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT t.priority AS priority, COUNT(*) AS total FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 0 GROUP BY t.priority',
    [userId],
  );

  final result = <String, int>{'High': 0, 'Medium': 0, 'Low': 0};
  for (final row in rows) {
    result[row['priority'] as String] = (row['total'] as int?) ?? 0;
  }
  return result;
}

/// Consecutive days (ending today or yesterday) on which at least one task
/// was completed. A completion today extends the streak; missing only today
/// does not break it yet, so the streak survives until midnight.
Future<int> completionStreak(int userId, {DateTime? now}) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT t.completedAtMillis AS completedAt FROM ${DbTables.tasks} t '
    'JOIN ${DbTables.courses} c ON c.id = t.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND t.isCompleted = 1 '
    'AND t.completedAtMillis IS NOT NULL',
    [userId],
  );

  final days = <DateTime>{};
  for (final row in rows) {
    final millis = row['completedAt'] as int?;
    if (millis == null) continue;
    days.add(AppDate.dayOnly(DateTime.fromMillisecondsSinceEpoch(millis)));
  }
  if (days.isEmpty) return 0;

  final today = AppDate.dayOnly(now ?? DateTime.now());
  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) return 0;

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
