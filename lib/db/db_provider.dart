import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:unimate/core/password_hasher.dart';
import 'package:unimate/db/tables.dart';

class DatabaseProvider {
  static Database? _db;
  static bool _ffiInitialised = false;

  /// Desktop platforms have no bundled sqlite, so they need the FFI factory.
  /// Safe to call more than once; a no-op on Android/iOS.
  static void initFfiIfNeeded() {
    if (_ffiInitialised) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialised = true;
  }

  /// Test hook: point the provider at a temporary file instead of the real
  /// application directory (which needs platform channels).
  @visibleForTesting
  static String? debugDbPathOverride;

  static Future<String> _resolveDbPath() async {
    final override = debugDbPathOverride;
    if (override != null) return override;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      return join(dir.path, DbTables.dbName);
    }
    return join(await getDatabasesPath(), DbTables.dbName);
  }

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;

    initFfiIfNeeded();
    final path = await _resolveDbPath();

    _db = await openDatabase(
      path,
      version: DbTables.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(DbTables.createUsers);
        await db.execute(DbTables.createCourses);
        await db.execute(DbTables.createTasks);
        await db.execute(DbTables.createResources);
        await db.execute(DbTables.createChatSessions);
        await db.execute(DbTables.createChatMessages);
        for (final index in DbTables.createIndexes) {
          await db.execute(index);
        }
      },
      onUpgrade: _upgrade,
    );

    return _db!;
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(DbTables.createUsers);
    }

    if (oldVersion < 3) {
      // Per-user courses + course colour.
      await _addColumn(
        db,
        DbTables.courses,
        'userId',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumn(
        db,
        DbTables.courses,
        'colorValue',
        'INTEGER NOT NULL DEFAULT 0',
      );

      // Richer tasks.
      await _addColumn(db, DbTables.tasks, 'notes', "TEXT NOT NULL DEFAULT ''");
      await _addColumn(
        db,
        DbTables.tasks,
        'reminderMinutesBefore',
        'INTEGER',
      );
      await _addColumn(db, DbTables.tasks, 'completedAtMillis', 'INTEGER');

      // Salted password hashes. Upgrading from v1 creates the users table with
      // the current definition just above, which already carries `salt`, so
      // this has to be conditional.
      await _addColumn(db, DbTables.users, 'salt', "TEXT NOT NULL DEFAULT ''");
      await _rehashLegacyPasswords(db);

      await db.execute(DbTables.createChatSessions);
      await db.execute(DbTables.createChatMessages);

      // Hand any pre-existing courses to the first registered account so that
      // data created before accounts existed is not orphaned.
      final firstUser = await db.query(
        DbTables.users,
        columns: ['id'],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (firstUser.isNotEmpty) {
        await db.update(
          DbTables.courses,
          {'userId': firstUser.first['id']},
          where: 'userId = 0',
        );
      }
    }

    for (final index in DbTables.createIndexes) {
      await db.execute(index);
    }
  }

  /// Adds a column only when it is missing.
  ///
  /// Migrations must be safe from every older version, and the steps overlap:
  /// the v2 step creates tables from the *current* definitions, so a v1
  /// database reaches the v3 step with some columns already present.
  /// `ALTER TABLE ... ADD COLUMN` is not idempotent and aborts the whole
  /// upgrade, leaving the app unable to open its database at all.
  static Future<void> _addColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Converts clear-text passwords written by v2 into salted hashes.
  static Future<void> _rehashLegacyPasswords(Database db) async {
    final rows = await db.query(
      DbTables.users,
      columns: ['id', 'password', 'salt'],
    );

    for (final row in rows) {
      final salt = (row['salt'] as String?) ?? '';
      if (salt.isNotEmpty) continue; // already migrated

      final newSalt = PasswordHasher.newSalt();
      final legacy = (row['password'] as String?) ?? '';
      await db.update(
        DbTables.users,
        {'salt': newSalt, 'password': PasswordHasher.hash(legacy, newSalt)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Closes the cached connection. Used by tests and on full sign-out flows.
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
