import 'package:flutter_test/flutter_test.dart';
import 'package:unimate/core/app_date.dart';
import 'package:unimate/models/course.dart';
import 'package:unimate/models/task.dart';

void main() {
  group('Task', () {
    Task taskDue(DateTime due, {int completed = 0, int? reminder}) => Task(
      courseId: 1,
      title: 'Essay',
      type: 'Assignment',
      dueDateMillis: due.millisecondsSinceEpoch,
      priority: 'High',
      isCompleted: completed,
      reminderMinutesBefore: reminder,
    );

    test('round-trips through a database map', () {
      final task = Task(
        id: 7,
        courseId: 3,
        title: 'Lab report',
        type: 'Project',
        dueDateMillis: 1700000000000,
        priority: 'Medium',
        isCompleted: 1,
        notes: 'Sections 1-3',
        reminderMinutesBefore: 60,
        completedAtMillis: 1700000100000,
      );

      final copy = Task.fromMap(task.toMap());

      expect(copy.id, task.id);
      expect(copy.title, task.title);
      expect(copy.notes, task.notes);
      expect(copy.reminderMinutesBefore, 60);
      expect(copy.completedAtMillis, task.completedAtMillis);
    });

    test('reads rows written before the v3 columns existed', () {
      final task = Task.fromMap({
        'id': 1,
        'courseId': 2,
        'title': 'Old task',
        'type': 'Exam',
        'dueDateMillis': 1700000000000,
        'priority': 'Low',
        'isCompleted': 0,
      });

      expect(task.notes, '');
      expect(task.reminderMinutesBefore, isNull);
      expect(task.completedAtMillis, isNull);
    });

    test('a past due date is overdue only while incomplete', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      expect(taskDue(past).isOverdue, isTrue);
      expect(taskDue(past, completed: 1).isOverdue, isFalse);
    });

    test('a future due date is never overdue', () {
      final future = DateTime.now().add(const Duration(days: 2));
      expect(taskDue(future).isOverdue, isFalse);
    });

    test('reminderTime is the due date minus the lead time', () {
      final due = DateTime(2026, 5, 4, 12, 0);
      expect(taskDue(due, reminder: 90).reminderTime, DateTime(2026, 5, 4, 10, 30));
      expect(taskDue(due).reminderTime, isNull);
    });

    test('copyWith can clear the reminder', () {
      final task = taskDue(DateTime(2026, 1, 1), reminder: 30);
      expect(task.copyWith(clearReminder: true).reminderMinutesBefore, isNull);
      expect(task.copyWith(title: 'New').reminderMinutesBefore, 30);
    });
  });

  group('Course', () {
    test('round-trips through a database map', () {
      const course = Course(
        id: 2,
        userId: 5,
        name: 'Databases',
        code: 'CS340',
        instructor: 'Dr. Rao',
        semester: 'Fall 2025',
        colorValue: 0xFF2563EB,
      );

      final copy = Course.fromMap(course.toMap());

      expect(copy.userId, 5);
      expect(copy.code, 'CS340');
      expect(copy.colorValue, 0xFF2563EB);
    });

    test('defaults userId and colour for v1/v2 rows', () {
      final course = Course.fromMap({
        'id': 1,
        'name': 'Algorithms',
        'code': 'CS300',
        'instructor': 'Dr. Lee',
        'semester': 'Fall 2025',
      });

      expect(course.userId, 0);
      expect(course.colorValue, 0);
    });
  });

  group('AppDate', () {
    test('dueLabel names today, tomorrow and yesterday', () {
      final now = DateTime(2026, 3, 10, 8, 0);
      expect(AppDate.dueLabel(DateTime(2026, 3, 10, 14), now: now), startsWith('Today'));
      expect(
        AppDate.dueLabel(DateTime(2026, 3, 11, 9), now: now),
        startsWith('Tomorrow'),
      );
      expect(
        AppDate.dueLabel(DateTime(2026, 3, 9, 9), now: now),
        startsWith('Yesterday'),
      );
    });

    test('dueLabel counts days for older dates', () {
      final now = DateTime(2026, 3, 10);
      expect(
        AppDate.dueLabel(DateTime(2026, 3, 5), now: now),
        startsWith('5 days ago'),
      );
    });

    test('startOfWeek returns the Monday of that week', () {
      // 2026-03-12 is a Thursday.
      expect(AppDate.startOfWeek(DateTime(2026, 3, 12)), DateTime(2026, 3, 9));
      expect(AppDate.startOfWeek(DateTime(2026, 3, 9)), DateTime(2026, 3, 9));
    });

    test('isSameDay ignores the time of day', () {
      expect(
        AppDate.isSameDay(DateTime(2026, 3, 9, 1), DateTime(2026, 3, 9, 23)),
        isTrue,
      );
      expect(
        AppDate.isSameDay(DateTime(2026, 3, 9), DateTime(2026, 3, 10)),
        isFalse,
      );
    });
  });
}
