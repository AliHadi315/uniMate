import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:unimate/db/tables.dart';

class DatabaseProvider {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbTables.dbName);

    _db = await openDatabase(
      path,
      version: DbTables.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(DbTables.createCourses);
        await db.execute(DbTables.createTasks);
        await db.execute(DbTables.createResources);
      },
    );

    return _db!;
  }
}
