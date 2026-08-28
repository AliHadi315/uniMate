import 'package:flutter/material.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../models/course.dart';
import '../models/task.dart';
import 'common.dart';

/// One task row. Shared by the course detail list, the agenda and the
/// dashboard so a task always looks and behaves the same way.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.course,
    this.onToggle,
    this.onTap,
    this.onDelete,
    this.showCourse = false,
  });

  final Task task;
  final Course? course;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = AppTheme.priorityColor(task.priority);
    final overdue = task.isOverdue;
    final accent = course == null
        ? priorityColor
        : AppTheme.courseColor(course!.colorValue, seedIndex: course!.id ?? 0);

    return AppTile(
      accent: accent,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        children: [
          if (onToggle != null)
            Checkbox(
              value: task.completed,
              onChanged: (v) => onToggle!(v ?? false),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.completed ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (showCourse && course != null) ...[
                        Flexible(
                          child: Text(
                            course!.code,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          '${task.type} • ${AppDate.dueLabel(task.dueDate)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: overdue
                                ? AppTheme.high
                                : scheme.onSurfaceVariant,
                            fontWeight: overdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.reminderMinutesBefore != null && !task.completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _reminderLabel(task.reminderMinutesBefore!),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Pill(text: task.priority, color: priorityColor, dense: true),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete task',
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  static String _reminderLabel(int minutes) {
    if (minutes == 0) return 'At due time';
    if (minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return '$days day${days == 1 ? '' : 's'} before';
    }
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'} before';
    }
    return '$minutes min before';
  }
}
