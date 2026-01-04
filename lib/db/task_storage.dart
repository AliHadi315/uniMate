import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';
import '../models/task.dart';

Future<int> insertTask(Task task) async {
  final db = await DatabaseProvider.getDatabase();
  final map = task.toMap()..remove('id');
  return db.insert(DbTables.tasks, map);
}

Future<List<Task>> loadTasksByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.tasks,
    where: 'courseId = ?',
    whereArgs: [courseId],
    orderBy: 'isCompleted ASC, dueDateMillis ASC',
  );
  return rows.map((e) => Task.fromMap(e)).toList();
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
    {'isCompleted': completed ? 1 : 0},
    where: 'id = ?',
    whereArgs: [taskId],
  );
}

Future<int> countPendingTasksByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();

  final rows = await db.query(
    'tasks',
    columns: ['id'],
    where: 'courseId = ? AND isCompleted = ?',
    whereArgs: [courseId, 0],
  );

  return rows.length;
}

// counts

Future<int> countAllTasks() async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(DbTables.tasks, columns: ['id']);
  return rows.length;
}

Future<int> countCompletedTasks() async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.tasks,
    columns: ['id'],
    where: 'isCompleted = ?',
    whereArgs: [1],
  );
  return rows.length;
}

Future<int> countPendingTasks() async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.tasks,
    columns: ['id'],
    where: 'isCompleted = ?',
    whereArgs: [0],
  );
  return rows.length;
}

Future<int> countOverdueTasks() async {
  final db = await DatabaseProvider.getDatabase();
  final now = DateTime.now().millisecondsSinceEpoch;
  final rows = await db.query(
    DbTables.tasks,
    columns: ['id'],
    where: 'isCompleted = ? AND dueDateMillis < ?',
    whereArgs: [0, now],
  );
  return rows.length;
}

Future<List<Task>> loadUpcomingTasks({int limit = 5}) async {
  final db = await DatabaseProvider.getDatabase();
  final now = DateTime.now().millisecondsSinceEpoch;

  final rows = await db.query(
    DbTables.tasks,
    where: 'isCompleted = ? AND dueDateMillis >= ?',
    whereArgs: [0, now],
    orderBy: 'dueDateMillis ASC',
    limit: limit,
  );

  return rows.map((e) => Task.fromMap(e)).toList();
}
