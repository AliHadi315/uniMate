import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

import '../models/course.dart';

/// Every query is scoped to a user id so two accounts on the same device do not
/// see each other's data.

Future<int> insertCourse(Course course) async {
  final db = await DatabaseProvider.getDatabase();
  final map = course.toMap()..remove('id');
  return db.insert(DbTables.courses, map);
}

/// Active courses by default; archived ones only when explicitly asked for,
/// so every existing caller keeps its "archived is invisible" behaviour.
Future<List<Course>> loadCourses(
  int userId, {
  bool includeArchived = false,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.courses,
    where: includeArchived
        ? 'userId = ?'
        : 'userId = ? AND archived = 0',
    whereArgs: [userId],
    orderBy: 'archived ASC, name ASC',
  );
  return rows.map(Course.fromMap).toList();
}

Future<int> setCourseArchived(int courseId, bool archived) async {
  final db = await DatabaseProvider.getDatabase();
  return db.update(
    DbTables.courses,
    {'archived': archived ? 1 : 0},
    where: 'id = ?',
    whereArgs: [courseId],
  );
}

Future<Course?> loadCourseById(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.courses,
    where: 'id = ?',
    whereArgs: [courseId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return Course.fromMap(rows.first);
}

Future<int> updateCourse(Course course) async {
  final db = await DatabaseProvider.getDatabase();
  final map = course.toMap()..remove('id');
  return db.update(
    DbTables.courses,
    map,
    where: 'id = ?',
    whereArgs: [course.id],
  );
}

Future<int> deleteCourseById(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(DbTables.courses, where: 'id = ?', whereArgs: [courseId]);
}

Future<int> countCourses(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM ${DbTables.courses} WHERE userId = ? AND archived = 0',
    [userId],
  );
  return (rows.first['c'] as int?) ?? 0;
}

/// Distinct semesters actually used by this account, for the filter dropdown.
Future<List<String>> loadSemesters(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT DISTINCT semester FROM ${DbTables.courses} WHERE userId = ? AND archived = 0 ORDER BY semester ASC',
    [userId],
  );
  return rows.map((r) => r['semester'] as String).toList();
}
