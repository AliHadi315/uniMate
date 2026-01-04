import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';
import '../models/resource.dart';

Future<int> insertResource(Resource resource) async {
  final db = await DatabaseProvider.getDatabase();
  final map = resource.toMap()..remove('id');
  return db.insert(DbTables.resources, map);
}

Future<List<Resource>> loadResourcesByCourse(int courseId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.resources,
    where: 'courseId = ?',
    whereArgs: [courseId],
    orderBy: 'title ASC',
  );
  return rows.map((e) => Resource.fromMap(e)).toList();
}

Future<int> updateResource(Resource resource) async {
  final db = await DatabaseProvider.getDatabase();
  final map = resource.toMap()..remove('id');
  return db.update(
    DbTables.resources,
    map,
    where: 'id = ?',
    whereArgs: [resource.id],
  );
}

Future<int> deleteResourceById(int resourceId) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(
    DbTables.resources,
    where: 'id = ?',
    whereArgs: [resourceId],
  );
}
