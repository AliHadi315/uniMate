import 'package:sqflite/sqflite.dart';

import 'package:unimate/core/password_hasher.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

/// Result of a sign-up attempt: either an error message or the new user row.
class InsertUserResult {
  final String? error;
  final Map<String, Object?>? user;

  const InsertUserResult.failure(this.error) : user = null;
  const InsertUserResult.success(this.user) : error = null;

  bool get ok => error == null;
}

/// Creates an account. The password is stored as a salted SHA-256 hash.
Future<InsertUserResult> insertUser({
  required String fullName,
  required String universityName,
  required String universityId,
  required String country,
  required String password,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final id = universityId.trim();

  final existing = await db.query(
    DbTables.users,
    where: 'universityId = ?',
    whereArgs: [id],
    limit: 1,
  );

  if (existing.isNotEmpty) {
    return const InsertUserResult.failure(
      'An account with this University ID already exists.',
    );
  }

  final salt = PasswordHasher.newSalt();
  final rowId = await db.insert(DbTables.users, {
    'fullName': fullName.trim(),
    'universityName': universityName.trim(),
    'universityId': id,
    'country': country.trim(),
    'password': PasswordHasher.hash(password, salt),
    'salt': salt,
  });

  await _adoptOrphanCourses(db, rowId);

  final rows = await db.query(
    DbTables.users,
    where: 'id = ?',
    whereArgs: [rowId],
    limit: 1,
  );
  return InsertUserResult.success(rows.first);
}

/// Courses created before accounts existed carry `userId = 0`. The migration
/// hands them to an existing account, but a database upgraded from v1 has no
/// accounts at all — so the first person to sign up adopts them instead of the
/// data silently disappearing. Later accounts get nothing.
Future<void> _adoptOrphanCourses(DatabaseExecutor db, int newUserId) async {
  final userCount = await db.rawQuery(
    'SELECT COUNT(*) AS total FROM ${DbTables.users}',
  );
  if (((userCount.first['total'] as int?) ?? 0) != 1) return;

  await db.update(
    DbTables.courses,
    {'userId': newUserId},
    where: 'userId = 0',
  );
}

/// Returns the user row when the credentials match, null otherwise.
Future<Map<String, Object?>?> findUserByCredentials({
  required String universityId,
  required String password,
}) async {
  final db = await DatabaseProvider.getDatabase();

  final rows = await db.query(
    DbTables.users,
    where: 'universityId = ?',
    whereArgs: [universityId.trim()],
    limit: 1,
  );

  if (rows.isEmpty) return null;

  final row = rows.first;
  final matches = PasswordHasher.verify(
    password: password,
    salt: (row['salt'] as String?) ?? '',
    expectedHash: (row['password'] as String?) ?? '',
  );

  return matches ? row : null;
}

Future<Map<String, Object?>?> findUserById(int id) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.users,
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first;
}

/// Updates the profile fields (never the password) of an existing account.
Future<int> updateUserProfile({
  required int id,
  required String fullName,
  required String universityName,
  required String country,
}) async {
  final db = await DatabaseProvider.getDatabase();
  return db.update(
    DbTables.users,
    {
      'fullName': fullName.trim(),
      'universityName': universityName.trim(),
      'country': country.trim(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// Replaces the password after verifying the current one.
/// Returns an error message, or null on success.
Future<String?> changePassword({
  required int id,
  required String currentPassword,
  required String newPassword,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final row = await findUserById(id);
  if (row == null) return 'Account not found.';

  final matches = PasswordHasher.verify(
    password: currentPassword,
    salt: (row['salt'] as String?) ?? '',
    expectedHash: (row['password'] as String?) ?? '',
  );
  if (!matches) return 'Current password is incorrect.';

  final salt = PasswordHasher.newSalt();
  await db.update(
    DbTables.users,
    {'password': PasswordHasher.hash(newPassword, salt), 'salt': salt},
    where: 'id = ?',
    whereArgs: [id],
  );
  return null;
}
