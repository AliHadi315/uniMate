import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../models/course.dart';
import '../models/task.dart';
import 'common.dart';

/// One task row. Shared by the course detail list, the agenda and the
/// dashboard so a task always looks and behaves the same way.
///
/// When [onToggle]/[onDelete] are provided the tile also supports swipe
/// gestures: swipe right to complete (or reopen), swipe left to delete.
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
    final tile = _tile(context);
    if (task.id == null || (onToggle == null && onDelete == null)) return tile;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: onDelete == null
          ? (onToggle == null
                ? DismissDirection.none
                : DismissDirection.startToEnd)
          : (onToggle == null
                ? DismissDirection.endToStart
                : DismissDirection.horizontal),
      // The lists reload asynchronously after a change, so never let the
      // Dismissible remove the row itself — trigger the action and snap back;
      // the reload takes the row out (or restyles it) a frame later.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.selectionClick();
          onToggle?.call(!task.completed);
        } else {
          HapticFeedback.mediumImpact();
          onDelete?.call();
        }
        return false;
      },
      background: _swipeHint(
        context,
        alignment: Alignment.centerLeft,
        color: task.completed ? AppTheme.medium : AppTheme.low,
        icon: task.completed ? Icons.undo : Icons.check_circle,
        label: task.completed ? 'Reopen' : 'Done',
      ),
      secondaryBackground: _swipeHint(
        context,
        alignment: Alignment.centerRight,
        color: AppTheme.high,
        icon: Icons.delete,
        label: 'Delete',
      ),
      child: tile,
    );
  }

  Widget _swipeHint(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = AppTheme.priorityColor(task.priority);
    final overdue = task.isOverdue;
    final accent = course == null
        ? priorityColor
        : AppTheme.courseColor(course!.colorValue, seedIndex: course!.id ?? 0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: task.completed ? 0.55 : 1,
      child: AppTile(
      accent: accent,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        children: [
          if (onToggle != null)
            Checkbox(
              value: task.completed,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onToggle!(v ?? false);
              },
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
