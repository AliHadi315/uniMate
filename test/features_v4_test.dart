import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:unimate/db/class_session_storage.dart';
import 'package:unimate/db/course_storage.dart';
import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/grade_storage.dart';
import 'package:unimate/db/task_storage.dart';
import 'package:unimate/db/user_storage.dart';
import 'package:unimate/models/class_session.dart';
import 'package:unimate/models/course.dart';
import 'package:unimate/models/grade.dart';
import 'package:unimate/models/task.dart';
import 'package:unimate/services/ai_task_parser.dart';
import 'package:unimate/services/backup_service.dart';
import 'package:unimate/services/task_actions.dart';

/// Integration tests for the v4 features: timetable, grades, recurrence,
/// archiving, streaks and backup.
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('unimate_v4_test');
    DatabaseProvider.debugDbPathOverride = p.join(tempDir.path, 'test.db');
  });

  tearDown(() async {
    await DatabaseProvider.close();
    DatabaseProvider.debugDbPathOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('archiving', () {
    test('archived courses vanish from every aggregate', () async {
      final userId = await createUser('S1');
      final keep = await createCourse(userId, 'KEEP1');
      final archive = await createCourse(userId, 'ARCH1');

      for (final courseId in [keep, archive]) {
        await insertTask(
          Task(
            courseId: courseId,
            title: 'Task',
            type: 'Assignment',
            dueDateMillis: DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
            priority: 'Medium',
            isCompleted: 0,
          ),
        );
      }

      await setCourseArchived(archive, true);

      expect((await loadCourses(userId)).map((c) => c.code), ['KEEP1']);
      expect(
        (await loadCourses(userId, includeArchived: true)).length,
        2,
      );
      expect(await countCourses(userId), 1);
      expect(await countAllTasks(userId), 1);
      expect((await loadAllTasks(userId)).single.course.code, 'KEEP1');

      // Restoring brings everything back.
      await setCourseArchived(archive, false);
      expect(await countAllTasks(userId), 2);
    });
  });

  group('class sessions', () {
    test('week and weekday queries are user-scoped and ordered', () async {
      final userId = await createUser('S1');
      final other = await createUser('S2');
      final mine = await createCourse(userId, 'CS101');
      final theirs = await createCourse(other, 'MA202');

      await insertClassSession(
        ClassSession(
          courseId: mine,
          weekday: 3,
          startMinutes: 11 * 60,
          endMinutes: 12 * 60,
        ),
      );
      await insertClassSession(
        ClassSession(
          courseId: mine,
          weekday: 3,
          startMinutes: 9 * 60,
          endMinutes: 10 * 60,
          location: 'B204',
        ),
      );
      await insertClassSession(
        ClassSession(
          courseId: theirs,
          weekday: 3,
          startMinutes: 9 * 60,
          endMinutes: 10 * 60,
        ),
      );

      final wednesday = await loadSessionsForWeekday(userId, 3);
      expect(wednesday.length, 2);
      expect(wednesday.first.session.startMinutes, 9 * 60);
      expect(wednesday.first.session.location, 'B204');
      expect(await loadSessionsForWeekday(userId, 4), isEmpty);

      final week = await loadWeekSessions(userId);
      expect(week.length, 2);
      expect(week.every((s) => s.course.code == 'CS101'), isTrue);
    });
  });

  group('grades', () {
    test('weighted average uses weights, falls back to plain mean', () {
      const weighted = [
        Grade(
          courseId: 1,
          title: 'Midterm',
          score: 80,
          maxScore: 100,
          weight: 30,
          createdAtMillis: 0,
        ),
        Grade(
          courseId: 1,
          title: 'Final',
          score: 90,
          maxScore: 100,
          weight: 60,
          createdAtMillis: 0,
        ),
      ];
      final summary = GradeSummary.of(weighted);
      // (80*30 + 90*60) / 90 = 86.67
      expect(summary.average, closeTo(86.67, 0.01));
      expect(summary.weightCovered, 90);

      const unweighted = [
        Grade(
          courseId: 1,
          title: 'Quiz 1',
          score: 8,
          maxScore: 10,
          createdAtMillis: 0,
        ),
        Grade(
          courseId: 1,
          title: 'Quiz 2',
          score: 6,
          maxScore: 10,
          createdAtMillis: 0,
        ),
      ];
      expect(GradeSummary.of(unweighted).average, closeTo(70, 0.01));
      expect(GradeSummary.of(const []).average, isNull);
    });

    test('a zero max score cannot divide by zero', () {
      const grade = Grade(
        courseId: 1,
        title: 'Broken',
        score: 5,
        maxScore: 0,
        createdAtMillis: 0,
      );
      expect(grade.percent, 0);
    });

    test('grades store round-trips and scopes by user', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');

      await insertGrade(
        Grade(
          courseId: courseId,
          title: 'Midterm',
          score: 42,
          maxScore: 50,
          weight: 40,
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final byCourse = await loadGradesByCourse(courseId);
      expect(byCourse.single.percent, closeTo(84, 0.01));

      final byUser = await loadGradesByUser(userId);
      expect(byUser[courseId]!.length, 1);
    });
  });

  group('recurring tasks', () {
    test('nextOccurrence skips past slots for overdue tasks', () {
      final now = DateTime(2026, 9, 2, 12);
      final task = Task(
        courseId: 1,
        title: 'Weekly quiz',
        type: 'Quiz',
        dueDateMillis: DateTime(2026, 8, 10, 9).millisecondsSinceEpoch,
        priority: 'Medium',
        isCompleted: 0,
        recurrenceDays: 7,
      );

      // 10 Aug + 7*n must land strictly after 2 Sep: 7 Sep.
      expect(task.nextOccurrence(now: now), DateTime(2026, 9, 7, 9));
    });

    test('completing a repeating task spawns the next occurrence', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');

      final due = DateTime.now().add(const Duration(days: 1));
      final id = await insertTask(
        Task(
          courseId: courseId,
          title: 'Weekly reading',
          type: 'Reading',
          dueDateMillis: due.millisecondsSinceEpoch,
          priority: 'Low',
          isCompleted: 0,
          recurrenceDays: 7,
        ),
      );
      final task = (await loadTaskById(id))!;

      final result = await TaskActions.setCompleted(
        task,
        completed: true,
        courseCode: 'CS101',
      );

      expect(result.spawnedTaskId, isNotNull);
      final spawned = (await loadTaskById(result.spawnedTaskId!))!;
      expect(spawned.completed, isFalse);
      expect(spawned.recurrenceDays, 7);
      // Compare at millisecond precision — DateTime.now() carries
      // microseconds that do not survive the millis round-trip.
      expect(
        spawned.dueDateMillis,
        due.add(const Duration(days: 7)).millisecondsSinceEpoch,
      );
      expect(await countAllTasks(userId), 2);

      // Undo removes the spawned occurrence and reopens the original.
      await TaskActions.undoCompletion(
        task,
        courseCode: 'CS101',
        spawnedTaskId: result.spawnedTaskId,
      );
      expect(await countAllTasks(userId), 1);
      expect((await loadTaskById(id))!.completed, isFalse);
    });

    test('completing a one-off task spawns nothing', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');
      final id = await insertTask(
        Task(
          courseId: courseId,
          title: 'One-off',
          type: 'Assignment',
          dueDateMillis: DateTime.now().millisecondsSinceEpoch,
          priority: 'Low',
          isCompleted: 0,
        ),
      );

      final result = await TaskActions.setCompleted(
        (await loadTaskById(id))!,
        completed: true,
        courseCode: 'CS101',
      );

      expect(result.spawnedTaskId, isNull);
      expect(await countAllTasks(userId), 1);
    });
  });

  group('streak', () {
    test('counts consecutive completion days, tolerating a quiet today',
        () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');
      final now = DateTime(2026, 9, 2, 15);

      Future<void> completedOn(DateTime day) => insertTask(
        Task(
          courseId: courseId,
          title: 'Done ${day.day}',
          type: 'Assignment',
          dueDateMillis: day.millisecondsSinceEpoch,
          priority: 'Low',
          isCompleted: 1,
          completedAtMillis: day.millisecondsSinceEpoch,
        ),
      );

      // Yesterday and the day before, nothing today.
      await completedOn(DateTime(2026, 9, 1, 10));
      await completedOn(DateTime(2026, 8, 31, 22));

      expect(await completionStreak(userId, now: now), 2);

      // A completion today extends it to 3.
      await completedOn(DateTime(2026, 9, 2, 9));
      expect(await completionStreak(userId, now: now), 3);

      // A gap breaks it: 29 Aug alone does not connect.
      await completedOn(DateTime(2026, 8, 28, 9));
      expect(await completionStreak(userId, now: now), 3);
    });

    test('is zero with no completions or a stale history', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');
      final now = DateTime(2026, 9, 2, 15);

      expect(await completionStreak(userId, now: now), 0);

      await insertTask(
        Task(
          courseId: courseId,
          title: 'Long ago',
          type: 'Assignment',
          dueDateMillis: DateTime(2026, 8, 20).millisecondsSinceEpoch,
          priority: 'Low',
          isCompleted: 1,
          completedAtMillis: DateTime(2026, 8, 20).millisecondsSinceEpoch,
        ),
      );
      expect(await completionStreak(userId, now: now), 0);
    });
  });

  group('backup', () {
    test('export and import round-trips a full account', () async {
      final userId = await createUser('S1');
      final courseId = await createCourse(userId, 'CS101');
      await insertTask(
        Task(
          courseId: courseId,
          title: 'Essay',
          type: 'Assignment',
          dueDateMillis: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          priority: 'High',
          isCompleted: 0,
          notes: 'chapter 3',
          recurrenceDays: 7,
        ),
      );
      await insertClassSession(
        ClassSession(
          courseId: courseId,
          weekday: 2,
          startMinutes: 600,
          endMinutes: 660,
          location: 'Lab 1',
        ),
      );
      await insertGrade(
        Grade(
          courseId: courseId,
          title: 'Quiz',
          score: 9,
          maxScore: 10,
          weight: 10,
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final json = await BackupService.exportJson(userId);

      // Import into a fresh account.
      final other = await createUser('S2');
      final imported = await BackupService.importJson(other, json);
      expect(imported, 1);

      final courses = await loadCourses(other);
      expect(courses.single.code, 'CS101');

      final tasks = await loadTasksByCourse(courses.single.id!);
      expect(tasks.single.title, 'Essay');
      expect(tasks.single.recurrenceDays, 7);

      final sessions = await loadSessionsByCourse(courses.single.id!);
      expect(sessions.single.location, 'Lab 1');

      final grades = await loadGradesByCourse(courses.single.id!);
      expect(grades.single.percent, closeTo(90, 0.01));

      // The source account is untouched.
      expect((await loadCourses(userId)).length, 1);
    });

    test('rejects files that are not UniMate backups', () async {
      final userId = await createUser('S1');

      expect(
        () => BackupService.importJson(userId, 'not json at all'),
        throwsFormatException,
      );
      expect(
        () => BackupService.importJson(userId, '{"app":"other"}'),
        throwsFormatException,
      );
      expect(
        () => BackupService.importJson(
          userId,
          '{"app":"unimate","courses":[]}',
        ),
        throwsFormatException,
      );
      // Nothing was written by the failed imports.
      expect(await loadCourses(userId, includeArchived: true), isEmpty);
    });
  });

  group('AI task parser', () {
    test('extracts a valid block and strips it from the prose', () {
      const reply = '''
Here is your plan for the week.

```unimate-tasks
[
  {"course":"CS340","title":"Read chapter 4","type":"Reading","dueInDays":2,
   "priority":"Medium","notes":"sections 4.1-4.3"},
  {"course":"MA101","title":"Problem set 2","type":"Assignment","dueInDays":5,
   "priority":"High","notes":""}
]
```''';

      final parsed = AiTaskParser.parse(reply);
      expect(parsed.text, 'Here is your plan for the week.');
      expect(parsed.tasks.length, 2);
      expect(parsed.tasks.first.courseCode, 'CS340');
      expect(parsed.tasks.first.dueInDays, 2);
      expect(parsed.tasks[1].priority, 'High');
    });

    test('a reply without a block yields no suggestions', () {
      final parsed = AiTaskParser.parse('Just study chapter 4 tonight.');
      expect(parsed.tasks, isEmpty);
      expect(parsed.text, 'Just study chapter 4 tonight.');
    });

    test('malformed or hostile blocks degrade safely', () {
      expect(
        AiTaskParser.parse('```unimate-tasks\nnot json\n```').tasks,
        isEmpty,
      );

      // Bad rows are dropped, invalid enums are normalised, caps enforced.
      final mixed = AiTaskParser.parse('''
```unimate-tasks
[
  {"course":"CS1","title":"ok","type":"Party","dueInDays":3,"priority":"Urgent"},
  {"course":"CS1","title":"","dueInDays":3},
  {"course":"CS1","title":"late","dueInDays":999},
  {"course":"CS1","title":"negative","dueInDays":-1}
]
```''');
      expect(mixed.tasks.length, 1);
      expect(mixed.tasks.single.type, 'Assignment');
      expect(mixed.tasks.single.priority, 'Medium');

      // At most ten suggestions survive.
      final many = List.generate(
        30,
        (i) => '{"course":"C","title":"t$i","dueInDays":1}',
      ).join(',');
      expect(
        AiTaskParser.parse('```unimate-tasks\n[$many]\n```').tasks.length,
        10,
      );
    });
  });

  group('migration to v4', () {
    test('a v3 database gains the new tables and columns', () async {
      final path = DatabaseProvider.debugDbPathOverride!;

      // Minimal v3 schema: what shipped before this change.
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE courses(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId INTEGER NOT NULL DEFAULT 0,
                name TEXT NOT NULL, code TEXT NOT NULL,
                instructor TEXT NOT NULL, semester TEXT NOT NULL,
                colorValue INTEGER NOT NULL DEFAULT 0);
            ''');
            await db.execute('''
              CREATE TABLE tasks(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                courseId INTEGER NOT NULL, title TEXT NOT NULL,
                type TEXT NOT NULL, dueDateMillis INTEGER NOT NULL,
                priority TEXT NOT NULL,
                isCompleted INTEGER NOT NULL DEFAULT 0,
                notes TEXT NOT NULL DEFAULT '',
                reminderMinutesBefore INTEGER, completedAtMillis INTEGER);
            ''');
            await db.execute('''
              CREATE TABLE resources(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                courseId INTEGER NOT NULL, title TEXT NOT NULL,
                type TEXT NOT NULL, value TEXT NOT NULL);
            ''');
            await db.execute('''
              CREATE TABLE users(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fullName TEXT NOT NULL, universityName TEXT NOT NULL,
                universityId TEXT NOT NULL UNIQUE, country TEXT NOT NULL,
                password TEXT NOT NULL, salt TEXT NOT NULL DEFAULT '');
            ''');
            await db.execute('''
              CREATE TABLE chat_sessions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId INTEGER NOT NULL DEFAULT 0, title TEXT NOT NULL,
                createdAtMillis INTEGER NOT NULL,
                updatedAtMillis INTEGER NOT NULL);
            ''');
            await db.execute('''
              CREATE TABLE chat_messages(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sessionId INTEGER NOT NULL, role TEXT NOT NULL,
                content TEXT NOT NULL, createdAtMillis INTEGER NOT NULL);
            ''');
          },
        ),
      );
      await legacy.insert('courses', {
        'userId': 1,
        'name': 'Old course',
        'code': 'OLD1',
        'instructor': 'Dr. Old',
        'semester': 'Fall 2025',
      });
      await legacy.close();

      final db = await DatabaseProvider.getDatabase();
      expect(await db.getVersion(), 4);

      final taskCols = await db.rawQuery('PRAGMA table_info(tasks)');
      expect(taskCols.where((c) => c['name'] == 'recurrenceDays').length, 1);
      expect(taskCols.where((c) => c['name'] == 'attachmentPath').length, 1);

      final courseCols = await db.rawQuery('PRAGMA table_info(courses)');
      expect(courseCols.where((c) => c['name'] == 'archived').length, 1);

      // The new tables work and the old row survived unarchived.
      expect((await loadCourses(1)).single.code, 'OLD1');
      expect(await loadWeekSessions(1), isEmpty);
    });
  });
}
