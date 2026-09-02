import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

import '../models/grade.dart';

Future<int> insertGrade(Grade grade) async {
  final db = await DatabaseProvider.getDatabase();
  final map = grade.toMap()..remove('id');
  return db.insert(DbTables.grades, map);
}

Future<int> updateGrade(Grade grade) async {
  final db = await DatabaseProvider.getDatabase();
  final map = grade.toMap()..remove('id');
  return db.update(
    DbTables.grades,
    map,
    where: 'id = ?',
    whereArgs: [grade.id],
  );
}

Future<int> deleteGradeById(int id) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(DbTables.grades, where: 'id = ?', whereArgs: [id]);
}

Future<List<Grade>> loadGradesByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.grades,
    where: 'courseId = ?',
    whereArgs: [courseId],
    orderBy: 'createdAtMillis DESC, id DESC',
  );
  return rows.map(Grade.fromMap).toList();
}

/// Grade lists per active course, keyed by courseId — one query for the
/// statistics screen instead of one per course.
Future<Map<int, List<Grade>>> loadGradesByUser(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT g.* FROM ${DbTables.grades} g '
    'JOIN ${DbTables.courses} c ON c.id = g.courseId '
    'WHERE c.userId = ? AND c.archived = 0',
    [userId],
  );

  final result = <int, List<Grade>>{};
  for (final row in rows) {
    final grade = Grade.fromMap(row);
    result.putIfAbsent(grade.courseId, () => []).add(grade);
  }
  return result;
}
