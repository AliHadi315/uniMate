import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../db/task_storage.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import 'phone_frame.dart';

/// Add or edit a task: title, type, priority, due date **and time**, notes and
/// an optional reminder.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.courseId,
    required this.existingTask,
    this.courseCode = '',
  });

  final int courseId;
  final Task? existingTask;
  final String courseCode;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  static const _reminderChoices = <int?, String>{
    null: 'No reminder',
    0: 'At due time',
    30: '30 minutes before',
    60: '1 hour before',
    180: '3 hours before',
    1440: '1 day before',
    2880: '2 days before',
    10080: '1 week before',
  };

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'Assignment';
  String _priority = 'Medium';
  late DateTime _dueDate;
  bool _completed = false;
  int? _reminderMinutes;
  bool _reminderDefaultApplied = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final task = widget.existingTask;
    if (task != null) {
      _titleCtrl.text = task.title;
      _notesCtrl.text = task.notes;
      _type = task.type;
      _priority = task.priority;
      _dueDate = task.dueDate;
      _completed = task.completed;
      _reminderMinutes = task.reminderMinutesBefore;
    } else {
      // Default to tomorrow at 09:00 rather than "now + 1 day".
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      _dueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
      _reminderMinutes = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // New tasks inherit the user's default reminder once settings are ready.
    // Applied only once, so picking "No reminder" is not silently undone by a
    // later dependency change.
    if (widget.existingTask == null && !_reminderDefaultApplied) {
      _reminderDefaultApplied = true;
      final settings = context.read<SettingsProvider>();
      if (settings.remindersEnabled) {
        _reminderMinutes = settings.defaultReminderMinutes;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueDate.hour,
        _dueDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _dueDate = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final settings = context.read<SettingsProvider>();
    final reminder = settings.remindersEnabled ? _reminderMinutes : null;

    try {
      final existing = widget.existingTask;
      final wasCompleted = existing?.completed ?? false;

      final task = Task(
        id: existing?.id,
        courseId: widget.courseId,
        title: _titleCtrl.text.trim(),
        type: _type,
        dueDateMillis: _dueDate.millisecondsSinceEpoch,
        priority: _priority,
        isCompleted: _completed ? 1 : 0,
        notes: _notesCtrl.text.trim(),
        reminderMinutesBefore: reminder,
        // Stamp the completion time when the switch is flipped on.
        completedAtMillis: _completed
            ? (wasCompleted
                  ? existing?.completedAtMillis
                  : DateTime.now().millisecondsSinceEpoch)
            : null,
      );

      final int savedId;
      if (existing == null) {
        savedId = await insertTask(task);
      } else {
        await updateTask(task);
        savedId = existing.id!;
      }

      await NotificationService.instance.scheduleForTask(
        task.copyWith(id: savedId),
        courseCode: widget.courseCode,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save the task: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTask != null;
    final scheme = Theme.of(context).colorScheme;
    final remindersOn = context.watch<SettingsProvider>().remindersEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit task' : 'New task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: PhoneFrame(
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (widget.courseCode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Pill(
                      text: widget.courseCode,
                      color: scheme.primary,
                      icon: Icons.school,
                    ),
                  ),

                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                    hintText: 'e.g. Chapter 4 problem set',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Assignment',
                            child: Text('Assignment'),
                          ),
                          DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                          DropdownMenuItem(
                            value: 'Project',
                            child: Text('Project'),
                          ),
                          DropdownMenuItem(value: 'Quiz', child: Text('Quiz')),
                          DropdownMenuItem(
                            value: 'Reading',
                            child: Text('Reading'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: ['Low', 'Medium', 'High']
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Row(
                                  children: [
                                    Container(
                                      height: 9,
                                      width: 9,
                                      decoration: BoxDecoration(
                                        color: AppTheme.priorityColor(p),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(p),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _priority = v ?? _priority),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _dueRow(),
                const SizedBox(height: 14),

                DropdownButtonFormField<int?>(
                  initialValue: _reminderMinutes,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Reminder',
                    helperText: remindersOn
                        ? null
                        : 'Reminders are switched off in settings',
                    prefixIcon: const Icon(
                      Icons.notifications_none,
                      size: 20,
                    ),
                  ),
                  items: _reminderChoices.entries
                      .map(
                        (e) => DropdownMenuItem<int?>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: remindersOn
                      ? (v) => setState(() => _reminderMinutes = v)
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesCtrl,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                    hintText: 'Requirements, chapters to read, links…',
                  ),
                ),
                const SizedBox(height: 6),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _completed,
                  onChanged: (v) => setState(() => _completed = v),
                  title: const Text('Mark as completed'),
                ),
                const SizedBox(height: 10),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Save changes' : 'Add task'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dueRow() {
    final surfaces = AppSurfaces.of(context);
    final scheme = Theme.of(context).colorScheme;
    final overdue = _dueDate.isBefore(DateTime.now()) && !_completed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppDate.formatDate(_dueDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      AppDate.dueLabel(_dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: overdue
                            ? AppTheme.high
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('Date'),
              ),
              TextButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(AppDate.formatTime(_dueDate)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
