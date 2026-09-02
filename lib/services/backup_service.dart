import 'dart:convert';

import '../db/class_session_storage.dart';
import '../db/course_storage.dart';
import '../db/db_provider.dart';
import '../db/grade_storage.dart';
import '../db/resource_storage.dart';
import '../db/tables.dart';
import '../db/task_storage.dart';
import '../models/course.dart';

/// Serialises one account's study data to JSON and back.
///
/// The backup nests everything under its course so ids never leave the
/// device; on import each course gets fresh ids and children are re-linked.
/// Accounts and chat history are deliberately excluded — backups may be
/// shared, and neither password hashes nor conversations belong in them.
class BackupService {
  const BackupService._();

  static const formatVersion = 1;

  static Future<String> exportJson(int userId) async {
    final courses = await loadCourses(userId, includeArchived: true);

    final courseDump = <Map<String, Object?>>[];
    for (final course in courses) {
      final id = course.id;
      if (id == null) continue;

      Map<String, Object?> strip(Map<String, Object?> map) => map
        ..remove('id')
        ..remove('courseId')
        ..remove('userId');

      courseDump.add({
        ...strip(course.toMap()),
        'tasks': [
          for (final task in await loadTasksByCourse(id)) strip(task.toMap()),
        ],
        'resources': [
          for (final r in await loadResourcesByCourse(id)) strip(r.toMap()),
        ],
        'classSessions': [
          for (final s in await loadSessionsByCourse(id)) strip(s.toMap()),
        ],
        'grades': [
          for (final g in await loadGradesByCourse(id)) strip(g.toMap()),
        ],
      });
    }

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'unimate',
      'format': formatVersion,
      'exportedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'courses': courseDump,
    });
  }

  /// Imports a backup into [userId]'s account. Everything is added — nothing
  /// existing is touched — and the whole import is one transaction, so a
  /// malformed file changes nothing at all.
  ///
  /// Returns the number of imported courses.
  static Future<int> importJson(int userId, String jsonText) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const FormatException('This file is not valid JSON.');
    }

    if (decoded is! Map || decoded['app'] != 'unimate') {
      throw const FormatException('This file is not a UniMate backup.');
    }
    final courses = decoded['courses'];
    if (courses is! List) {
      throw const FormatException('The backup contains no course list.');
    }

    final db = await DatabaseProvider.getDatabase();

    return db.transaction((txn) async {
      var imported = 0;

      for (final entry in courses) {
        if (entry is! Map) continue;
        final map = entry.cast<String, Object?>();

        final course = Course.fromMap({
          'name': map['name'] ?? 'Imported course',
          'code': map['code'] ?? '',
          'instructor': map['instructor'] ?? '',
          'semester': map['semester'] ?? '',
          'colorValue': map['colorValue'] ?? 0,
          'archived': map['archived'] ?? 0,
        });
        final courseId = await txn.insert(DbTables.courses, {
          ...course.toMap()..remove('id'),
          'userId': userId,
        });
        imported++;

        Future<void> insertChildren(
          String key,
          String table,
          Set<String> requiredFields, {
          Map<String, Object?> defaults = const {},
        }) async {
          final children = map[key];
          if (children is! List) return;
          for (final child in children) {
            if (child is! Map) continue;
            final childMap = child.cast<String, Object?>();
            if (!requiredFields.every(childMap.containsKey)) continue;
            await txn.insert(table, {
              ...defaults,
              ...childMap..remove('id'),
              'courseId': courseId,
            });
          }
        }

        await insertChildren('tasks', DbTables.tasks, {
          'title',
          'type',
          'dueDateMillis',
          'priority',
        });
        await insertChildren('resources', DbTables.resources, {
          'title',
          'type',
          'value',
        });
        await insertChildren('classSessions', DbTables.classSessions, {
          'weekday',
          'startMinutes',
          'endMinutes',
        });
        await insertChildren(
          'grades',
          DbTables.grades,
          {'title', 'score', 'maxScore'},
          defaults: {
            'weight': 0,
            'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }

      if (imported == 0) {
        throw const FormatException('The backup contains no courses.');
      }
      return imported;
    });
  }
}
