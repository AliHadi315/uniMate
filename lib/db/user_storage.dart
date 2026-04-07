import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

// Save a new user to the database
Future<String?> insertUser({
  required String fullName,
  required String universityName,
  required String universityId,
  required String country,
  required String password,
}) async {
  final db = await DatabaseProvider.getDatabase();

  // check if universityId already exists
  final existing = await db.query(
    DbTables.users,
    where: 'universityId = ?',
    whereArgs: [universityId.trim()],
    limit: 1,
  );

  if (existing.isNotEmpty) {
    return 'Account with this University ID already exists.';
  }

  await db.insert(DbTables.users, {
    'fullName': fullName.trim(),
    'universityName': universityName.trim(),
    'universityId': universityId.trim(),
    'country': country.trim(),
    'password': password,
  });

  return null; // no error
}

// Returns the user map if credentials match, null otherwise
Future<Map<String, Object?>?> findUserByCredentials({
  required String universityId,
  required String password,
}) async {
  final db = await DatabaseProvider.getDatabase();

  final rows = await db.query(
    DbTables.users,
    where: 'universityId = ? AND password = ?',
    whereArgs: [universityId.trim(), password],
    limit: 1,
  );

  if (rows.isEmpty) return null;
  return rows.first;
}
