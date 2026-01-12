import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';
import '../models/course.dart';

//Create Courses
Future<int> insertCourse(Course course) async {
  final db = await DatabaseProvider.getDatabase();
  final map = course.toMap()..remove('id');
  return db.insert(DbTables.courses, map);
}

//Read Courses
Future<List<Course>> loadCourses() async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(DbTables.courses, orderBy: 'name ASC');
  return rows.map((e) => Course.fromMap(e)).toList();
}

//Update Courses
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

//Delete Courses
Future<int> deleteCourseById(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(DbTables.courses, where: 'id = ?', whereArgs: [courseId]);
}
