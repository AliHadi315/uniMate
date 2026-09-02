import '../db/task_storage.dart';
import '../models/task.dart';
import 'notification_service.dart';

/// Result of completing a task: the id of the next occurrence when the task
/// repeats, so callers can offer a correct Undo.
class CompletionResult {
  final int? spawnedTaskId;

  const CompletionResult({this.spawnedTaskId});
}

/// One place for the "complete / reopen a task" side effects, shared by every
/// screen: reminder bookkeeping and spawning the next occurrence of a
/// repeating task.
class TaskActions {
  const TaskActions._();

  static Future<CompletionResult> setCompleted(
    Task task, {
    required bool completed,
    required String courseCode,
  }) async {
    final id = task.id;
    if (id == null) return const CompletionResult();

    await setTaskCompleted(id, completed);

    if (!completed) {
      // Reopened: put its reminder back if one is configured.
      final refreshed = await loadTaskById(id);
      if (refreshed != null) {
        await NotificationService.instance.scheduleForTask(
          refreshed,
          courseCode: courseCode,
        );
      }
      return const CompletionResult();
    }

    await NotificationService.instance.cancelForTask(id);

    // A repeating task rolls over to its next occurrence.
    if (!task.repeats) return const CompletionResult();

    final next = task.copyWith(
      id: null,
      dueDateMillis: task.nextOccurrence().millisecondsSinceEpoch,
      isCompleted: 0,
      clearCompletedAt: true,
    );
    // copyWith cannot null the id, so build the row explicitly.
    final spawnedId = await insertTask(
      Task(
        courseId: next.courseId,
        title: next.title,
        type: next.type,
        dueDateMillis: next.dueDateMillis,
        priority: next.priority,
        isCompleted: 0,
        notes: next.notes,
        reminderMinutesBefore: next.reminderMinutesBefore,
        recurrenceDays: next.recurrenceDays,
        attachmentPath: next.attachmentPath,
      ),
    );

    await NotificationService.instance.scheduleForTask(
      next.copyWith(id: spawnedId),
      courseCode: courseCode,
    );

    return CompletionResult(spawnedTaskId: spawnedId);
  }

  /// Undo for [setCompleted]: reopens the task and removes the occurrence the
  /// completion spawned, so a mis-tap on a repeating task leaves no duplicate.
  static Future<void> undoCompletion(
    Task task, {
    required String courseCode,
    int? spawnedTaskId,
  }) async {
    final id = task.id;
    if (id == null) return;

    if (spawnedTaskId != null) {
      await deleteTaskById(spawnedTaskId);
      await NotificationService.instance.cancelForTask(spawnedTaskId);
    }

    await setTaskCompleted(id, false);
    final refreshed = await loadTaskById(id);
    if (refreshed != null) {
      await NotificationService.instance.scheduleForTask(
        refreshed,
        courseCode: courseCode,
      );
    }
  }
}
