import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

import '../models/class_session.dart';
import '../models/course.dart';

/// A class slot joined with its course, for the timetable views.
class SessionWithCourse {
  final ClassSession session;
  final Course course;

  const SessionWithCourse({required this.session, required this.course});
}

const _sessionColumns =
    's.id AS id, s.courseId AS courseId, s.weekday AS weekday, '
    's.startMinutes AS startMinutes, s.endMinutes AS endMinutes, '
    's.location AS location';

const _courseColumns =
    'c.id AS c_id, c.userId AS c_userId, c.name AS c_name, c.code AS c_code, '
    'c.instructor AS c_instructor, c.semester AS c_semester, '
    'c.colorValue AS c_colorValue, c.archived AS c_archived';

SessionWithCourse _joinedRow(Map<String, Object?> row) => SessionWithCourse(
  session: ClassSession.fromMap(row),
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

Future<int> insertClassSession(ClassSession session) async {
  final db = await DatabaseProvider.getDatabase();
  final map = session.toMap()..remove('id');
  return db.insert(DbTables.classSessions, map);
}

Future<int> updateClassSession(ClassSession session) async {
  final db = await DatabaseProvider.getDatabase();
  final map = session.toMap()..remove('id');
  return db.update(
    DbTables.classSessions,
    map,
    where: 'id = ?',
    whereArgs: [session.id],
  );
}

Future<int> deleteClassSessionById(int id) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(DbTables.classSessions, where: 'id = ?', whereArgs: [id]);
}

/// Every class slot for [userId]'s active courses, ordered for a week view.
Future<List<SessionWithCourse>> loadWeekSessions(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_sessionColumns, $_courseColumns '
    'FROM ${DbTables.classSessions} s '
    'JOIN ${DbTables.courses} c ON c.id = s.courseId '
    'WHERE c.userId = ? AND c.archived = 0 '
    'ORDER BY s.weekday ASC, s.startMinutes ASC',
    [userId],
  );
  return rows.map(_joinedRow).toList();
}

/// Slots on one weekday (1=Mon … 7=Sun) — the dashboard's "today's classes".
Future<List<SessionWithCourse>> loadSessionsForWeekday(
  int userId,
  int weekday,
) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.rawQuery(
    'SELECT $_sessionColumns, $_courseColumns '
    'FROM ${DbTables.classSessions} s '
    'JOIN ${DbTables.courses} c ON c.id = s.courseId '
    'WHERE c.userId = ? AND c.archived = 0 AND s.weekday = ? '
    'ORDER BY s.startMinutes ASC',
    [userId, weekday],
  );
  return rows.map(_joinedRow).toList();
}

Future<List<ClassSession>> loadSessionsByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.classSessions,
    where: 'courseId = ?',
    whereArgs: [courseId],
    orderBy: 'weekday ASC, startMinutes ASC',
  );
  return rows.map(ClassSession.fromMap).toList();
}
