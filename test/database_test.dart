import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:unimate/db/course_storage.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/resource_storage.dart';
import 'package:unimate/db/tables.dart';
import 'package:unimate/db/task_storage.dart';
import 'package:unimate/db/user_storage.dart';
import 'package:unimate/models/course.dart';
import 'package:unimate/models/resource.dart';
import 'package:unimate/models/task.dart';

/// Exercises the storage layer against a real (temporary) sqlite file.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  Future<int> createUser(String id) async {
    final result = await insertUser(
      fullName: 'Student $id',
      universityName: 'Test University',
      universityId: id,
      country: 'Testland',
      password: 'password123',
    );
    return result.user!['id'] as int;
  }

  Future<int> createCourse(int userId, String code) => insertCourse(
    Course(
      userId: userId,
      name: 'Course $code',
      code: code,
      instructor: 'Dr. Test',
      semester: 'Fall 2025',
    ),
  );

  Future<int> createTask(
    int courseId, {
    required String title,
    required DateTime due,
    bool completed = false,
    String priority = 'Medium',
  }) => insertTask(
    Task(
      courseId: courseId,
      title: title,
      type: 'Assignment',
      dueDateMillis: due.millisecondsSinceEpoch,
      priority: priority,
      isCompleted: completed ? 1 : 0,
      completedAtMillis: completed
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    ),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('unimate_test');
    DatabaseProvider.debugDbPathOverride = p.join(tempDir.path, 'test.db');
  });

  tearDown(() async {
    await DatabaseProvider.close();
    DatabaseProvider.debugDbPathOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('accounts', () {
    test('sign-up stores a hash, never the password', () async {
      final id = await createUser('S1');

      final row = await findUserById(id);
      expect(row!['password'], isNot('password123'));
      expect((row['salt'] as String).isNotEmpty, isTrue);
    });

    test('duplicate university IDs are rejected', () async {
      await createUser('S1');
      final second = await insertUser(
        fullName: 'Someone Else',
        universityName: 'Other University',
        universityId: 'S1',
        country: 'Testland',
        password: 'different',
      );

      expect(second.ok, isFalse);
      expect(second.error, contains('already exists'));
    });

    test('login only succeeds with the right password', () async {
      await createUser('S1');

      expect(
        await findUserByCredentials(universityId: 'S1', password: 'password123'),
        isNotNull,
      );
      expect(
        await findUserByCredentials(universityId: 'S1', password: 'nope'),
        isNull,
      );
      expect(
        await findUserByCredentials(universityId: 'S404', password: 'password123'),
        isNull,
      );
    });

    test('changing the password invalidates the old one', () async {
      final id = await createUser('S1');

      final error = await changePassword(
        id: id,
        currentPassword: 'password123',
        newPassword: 'brand-new',
      );
      expect(error, isNull);

      expect(
        await findUserByCredentials(universityId: 'S1', password: 'password123'),
        isNull,
      );
      expect(
        await findUserByCredentials(universityId: 'S1', password: 'brand-new'),
        isNotNull,
      );
    });

    test('changing the password requires the current one', () async {
      final id = await createUser('S1');
      final error = await changePassword(
        id: id,
        currentPassword: 'wrong',
        newPassword: 'brand-new',
      );
      expect(error, contains('incorrect'));
    });
  });

  group('per-user scoping', () {
    test('each account only sees its own courses and tasks', () async {
      final alice = await createUser('A1');
      final bob = await createUser('B1');

      final aliceCourse = await createCourse(alice, 'CS101');
      final bobCourse = await createCourse(bob, 'MA202');

      await createTask(
        aliceCourse,
        title: 'Alice task',
        due: DateTime.now().add(const Duration(days: 1)),
      );
      await createTask(
        bobCourse,
        title: 'Bob task',
        due: DateTime.now().add(const Duration(days: 1)),
      );

      final aliceCourses = await loadCourses(alice);
      expect(aliceCourses.map((c) => c.code), ['CS101']);

      final aliceTasks = await loadAllTasks(alice);
      expect(aliceTasks.map((t) => t.task.title), ['Alice task']);
      expect(await countAllTasks(alice), 1);
      expect(await countAllTasks(bob), 1);
    });
  });

  group('task counters', () {
    late int userId;
    late int courseId;

    setUp(() async {
      userId = await createUser('S1');
      courseId = await createCourse(userId, 'CS101');

      final now = DateTime.now();
      await createTask(
        courseId,
        title: 'Overdue',
        due: now.subtract(const Duration(days: 2)),
        priority: 'High',
      );
      await createTask(
        courseId,
        title: 'Due today',
        due: now.add(const Duration(minutes: 30)),
        priority: 'High',
      );
      await createTask(
        courseId,
        title: 'Next week',
        due: now.add(const Duration(days: 7)),
        priority: 'Low',
      );
      await createTask(
        courseId,
        title: 'Finished',
        due: now.add(const Duration(days: 3)),
        completed: true,
      );
    });

    test('counts split pending, overdue and completed', () async {
      expect(await countAllTasks(userId), 4);
      expect(await countCompletedTasks(userId), 1);
      expect(await countOverdueTasks(userId), 1);
      expect(await countPendingTasks(userId), 2);
      expect(await countPendingTasksByCourse(courseId), 3);
    });

    test('due-today only counts open tasks that are due today', () async {
      expect(await countDueTodayTasks(userId), 1);
    });

    test('upcoming excludes completed and overdue tasks', () async {
      final upcoming = await loadUpcomingTasks(userId);
      expect(upcoming.map((t) => t.task.title), ['Due today', 'Next week']);
    });

    test('overdue list only holds past-due open tasks', () async {
      final overdue = await loadOverdueTasks(userId);
      expect(overdue.map((t) => t.task.title), ['Overdue']);
    });

    test('pendingByPriority groups the open tasks', () async {
      final byPriority = await pendingByPriority(userId);
      expect(byPriority['High'], 2);
      expect(byPriority['Low'], 1);
      expect(byPriority['Medium'], 0);
    });

    test('completing a task stamps completedAtMillis', () async {
      final tasks = await loadTasksByCourse(courseId);
      final target = tasks.firstWhere((t) => t.title == 'Next week');

      await setTaskCompleted(target.id!, true);
      final done = await loadTaskById(target.id!);
      expect(done!.completed, isTrue);
      expect(done.completedAtMillis, isNotNull);

      await setTaskCompleted(target.id!, false);
      final reopened = await loadTaskById(target.id!);
      expect(reopened!.completed, isFalse);
      expect(reopened.completedAtMillis, isNull);
    });

    test('completionsPerDay buckets by day, newest last', () async {
      final week = await completionsPerDay(userId);
      expect(week.length, 7);
      expect(week.last, 1); // the "Finished" task was completed just now
    });
  });

  group('cascade delete', () {
    test('deleting a course removes its tasks and resources', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');

      await createTask(
        courseId,
        title: 'Task',
        due: DateTime.now().add(const Duration(days: 1)),
      );
      await insertResource(
        Resource(
          courseId: courseId,
          title: 'Slides',
          type: 'Link',
          value: 'https://example.com',
        ),
      );

      await deleteCourseById(courseId);

      expect(await loadTasksByCourse(courseId), isEmpty);
      expect(await loadResourcesByCourse(courseId), isEmpty);
      expect(await countAllTasks(userId), 0);
    });
  });

  group('migration from v2', () {
    test('rehashes passwords and hands old courses to the first user', () async {
      final path = DatabaseProvider.debugDbPathOverride!;

      // Build a database exactly as version 2 left it.
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE ${DbTables.courses}(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                code TEXT NOT NULL,
                instructor TEXT NOT NULL,
                semester TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE ${DbTables.tasks}(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                courseId INTEGER NOT NULL,
                title TEXT NOT NULL,
                type TEXT NOT NULL,
                dueDateMillis INTEGER NOT NULL,
                priority TEXT NOT NULL,
                isCompleted INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(courseId) REFERENCES ${DbTables.courses}(id)
                  ON DELETE CASCADE
              );
            ''');
            await db.execute('''
              CREATE TABLE ${DbTables.resources}(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                courseId INTEGER NOT NULL,
                title TEXT NOT NULL,
                type TEXT NOT NULL,
                value TEXT NOT NULL,
                FOREIGN KEY(courseId) REFERENCES ${DbTables.courses}(id)
                  ON DELETE CASCADE
              );
            ''');
            await db.execute('''
              CREATE TABLE ${DbTables.users}(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fullName TEXT NOT NULL,
                universityName TEXT NOT NULL,
                universityId TEXT NOT NULL UNIQUE,
                country TEXT NOT NULL,
                password TEXT NOT NULL
              );
            ''');
          },
        ),
      );

      await legacy.insert(DbTables.users, {
        'fullName': 'Legacy Student',
        'universityName': 'Old University',
        'universityId': 'L1',
        'country': 'Testland',
        'password': 'plaintext-secret', // how v2 stored it
      });
      final legacyCourseId = await legacy.insert(DbTables.courses, {
        'name': 'Legacy Course',
        'code': 'LEG100',
        'instructor': 'Dr. Old',
        'semester': 'Fall 2025',
      });
      await legacy.insert(DbTables.tasks, {
        'courseId': legacyCourseId,
        'title': 'Legacy task',
        'type': 'Assignment',
        'dueDateMillis': DateTime.now().millisecondsSinceEpoch,
        'priority': 'High',
        'isCompleted': 0,
      });
      await legacy.close();

      // Opening through the provider runs the v3 upgrade.
      final db = await DatabaseProvider.getDatabase();
      final userRow = (await db.query(DbTables.users)).first;
      final userId = userRow['id'] as int;

      // The clear-text password is gone, but the old password still works.
      expect(userRow['password'], isNot('plaintext-secret'));
      expect((userRow['salt'] as String).isNotEmpty, isTrue);
      expect(
        await findUserByCredentials(
          universityId: 'L1',
          password: 'plaintext-secret',
        ),
        isNotNull,
      );

      // Pre-existing data is now owned by that account rather than orphaned.
      final courses = await loadCourses(userId);
      expect(courses.map((c) => c.code), ['LEG100']);
      expect(courses.first.colorValue, 0);

      final tasks = await loadAllTasks(userId);
      expect(tasks.single.task.title, 'Legacy task');
      expect(tasks.single.task.notes, '');
      expect(tasks.single.task.reminderMinutesBefore, isNull);
    });
  });
}
