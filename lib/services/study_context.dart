import '../core/app_date.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';

/// Builds a compact plain-text summary of the student's courses and open
/// tasks. It is sent to the assistant as system context so answers such as
/// "what should I work on tonight?" use real data.
class StudyContextBuilder {
  const StudyContextBuilder._();

  static Future<String> build(int userId, {int taskLimit = 25}) async {
    if (userId < 0) return '';

    final courses = await loadCourses(userId);
    if (courses.isEmpty) return 'No courses have been added yet.';

    final entries = await loadAllTasks(userId);
    final open = entries.where((e) => !e.task.completed).toList()
      ..sort((a, b) => a.task.dueDateMillis.compareTo(b.task.dueDateMillis));

    final buffer = StringBuffer()..writeln('Courses:');
    for (final course in courses) {
      buffer.writeln(
        '- ${course.code} — ${course.name} (${course.instructor}, '
        '${course.semester})',
      );
    }

    final done = entries.length - open.length;
    buffer
      ..writeln()
      ..writeln(
        'Tasks: ${entries.length} total, $done completed, ${open.length} open.',
      );

    if (open.isEmpty) {
      buffer.writeln('No open tasks.');
      return buffer.toString();
    }

    buffer.writeln('Open tasks, soonest first:');
    for (final entry in open.take(taskLimit)) {
      final task = entry.task;
      final status = task.isOverdue ? 'OVERDUE' : 'due';
      buffer.writeln(
        '- [${entry.course.code}] ${task.title} (${task.type}, '
        '${task.priority} priority) $status '
        '${AppDate.formatDateTime(task.dueDate)}',
      );
    }

    if (open.length > taskLimit) {
      buffer.writeln('…and ${open.length - taskLimit} more.');
    }

    return buffer.toString();
  }
}
