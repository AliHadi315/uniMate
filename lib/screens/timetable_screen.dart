import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../db/class_session_storage.dart';
import '../db/course_storage.dart';
import '../models/class_session.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../widgets/common.dart';
import 'phone_frame.dart';

/// Weekly class schedule: every lecture/lab slot grouped by weekday.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<SessionWithCourse> _sessions = [];
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().userId;
      final sessions = await loadWeekSessions(userId);
      final courses = await loadCourses(userId);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _courses = courses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openSessionDialog({SessionWithCourse? existing}) async {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a course before adding classes.')),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SessionDialog(
        courses: _courses,
        existing: existing?.session,
      ),
    );

    if (saved == true && mounted) {
      await _load();
      if (mounted) context.read<DataRefresh>().bump();
    }
  }

  Future<void> _delete(SessionWithCourse entry) async {
    final id = entry.session.id;
    if (id == null) return;

    await deleteClassSessionById(id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    context.read<DataRefresh>().bump();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${entry.course.code} on '
            '${entry.session.weekdayName}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await insertClassSession(entry.session);
            if (mounted) {
              await _load();
              if (mounted) context.read<DataRefresh>().bump();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final byDay = <int, List<SessionWithCourse>>{};
    for (final entry in _sessions) {
      byDay.putIfAbsent(entry.session.weekday, () => []).add(entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSessionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Class'),
      ),
      body: SafeArea(
        child: PhoneFrame(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load the timetable',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                )
              : _sessions.isEmpty
              ? EmptyState(
                  icon: Icons.calendar_view_week,
                  title: 'No classes yet',
                  message:
                      'Add your weekly lectures and labs; today\'s classes '
                      'appear on the dashboard.',
                  action: FilledButton.icon(
                    onPressed: () => _openSessionDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add class'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    for (var day = 1; day <= 7; day++)
                      if (byDay.containsKey(day)) ...[
                        _dayHeader(day, isToday: day == today),
                        ...byDay[day]!.map(_sessionTile),
                      ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _dayHeader(int day, {required bool isToday}) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text(
            ClassSession.weekdayNames[day - 1].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Pill(text: 'Today', color: scheme.primary, dense: true),
          ],
          const SizedBox(width: 8),
          Expanded(child: Divider(color: AppSurfaces.of(context).outline)),
        ],
      ),
    );
  }

  Widget _sessionTile(SessionWithCourse entry) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTheme.courseColor(
      entry.course.colorValue,
      seedIndex: entry.course.id ?? 0,
    );

    return AppTile(
      accent: accent,
      onTap: () => _openSessionDialog(existing: entry),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ClassSession.formatMinutes(entry.session.startMinutes),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  ClassSession.formatMinutes(entry.session.endMinutes),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.course.code,
                  style: TextStyle(fontWeight: FontWeight.w600, color: accent),
                ),
                Text(
                  entry.course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (entry.session.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        entry.session.location,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove class',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(entry),
          ),
        ],
      ),
    );
  }
}

/// Add/edit one weekly class slot.
class _SessionDialog extends StatefulWidget {
  const _SessionDialog({required this.courses, this.existing});

  final List<Course> courses;
  final ClassSession? existing;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  final _locationCtrl = TextEditingController();
  late int _courseId;
  late int _weekday;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _courseId = existing?.courseId ?? widget.courses.first.id!;
    // A course may have been archived since the slot was created; fall back so
    // the dropdown always has a valid value.
    if (!widget.courses.any((c) => c.id == _courseId)) {
      _courseId = widget.courses.first.id!;
    }
    _weekday = existing?.weekday ?? DateTime.now().weekday;
    _start = existing?.start ?? const TimeOfDay(hour: 9, minute: 0);
    _end = existing?.end ?? const TimeOfDay(hour: 10, minute: 0);
    _locationCtrl.text = existing?.location ?? '';
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        // Keep the slot at least 30 minutes long when start passes end.
        if (_minutes(_end) <= _minutes(_start)) {
          final endMinutes = (_minutes(_start) + 60).clamp(0, 23 * 60 + 59);
          _end = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_minutes(_end) <= _minutes(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The class must end after it starts.')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final session = ClassSession(
        id: widget.existing?.id,
        courseId: _courseId,
        weekday: _weekday,
        startMinutes: _minutes(_start),
        endMinutes: _minutes(_end),
        location: _locationCtrl.text.trim(),
      );

      if (widget.existing == null) {
        await insertClassSession(session);
      } else {
        await updateClassSession(session);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add class' : 'Edit class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _courseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Course'),
              items: widget.courses
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.code} — ${c.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _courseId = v ?? _courseId),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(
                    value: day,
                    child: Text(ClassSession.weekdayNames[day - 1]),
                  ),
              ],
              onChanged: (v) => setState(() => _weekday = v ?? _weekday),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: true),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      ClassSession.formatMinutes(_minutes(_start)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: false),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(ClassSession.formatMinutes(_minutes(_end))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Room B204',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
