import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../db/task_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'phone_frame.dart';
import 'task_form_screen.dart';

enum AgendaRange { today, week, upcoming, overdue, all }

/// Every task across every course, grouped by day.
///
/// Before this screen existed a task could only be reached by opening its
/// course first, which made "what is due this week?" hard to answer.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<TaskWithCourse> _entries = [];
  bool _loading = true;
  String? _error;
  int _revision = -1;

  AgendaRange _range = AgendaRange.week;
  bool _hideCompleted = true;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = Provider.of<DataRefresh>(context).revision;
    if (revision != _revision) {
      _revision = revision;
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().userId;
      final entries = await loadAllTasks(userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  List<TaskWithCourse> _visible() {
    final now = DateTime.now();
    final today = AppDate.dayOnly(now);
    final weekEnd = today.add(const Duration(days: 7));
    final query = _query.trim().toLowerCase();

    return _entries.where((e) {
      final task = e.task;
      if (_hideCompleted && task.completed) return false;

      final due = task.dueDate;
      final inRange = switch (_range) {
        AgendaRange.today => AppDate.isSameDay(due, now),
        AgendaRange.week => !due.isBefore(today) && due.isBefore(weekEnd),
        AgendaRange.upcoming => !due.isBefore(now),
        AgendaRange.overdue => !task.completed && due.isBefore(now),
        AgendaRange.all => true,
      };
      if (!inRange) return false;

      if (query.isEmpty) return true;
      return task.title.toLowerCase().contains(query) ||
          task.notes.toLowerCase().contains(query) ||
          task.type.toLowerCase().contains(query) ||
          e.course.code.toLowerCase().contains(query) ||
          e.course.name.toLowerCase().contains(query);
    }).toList()..sort((a, b) {
      final byDate = a.task.dueDateMillis.compareTo(b.task.dueDateMillis);
      if (byDate != 0) return byDate;
      return a.task.title.compareTo(b.task.title);
    });
  }

  /// Groups tasks under a day heading, keeping the sorted order.
  Map<DateTime, List<TaskWithCourse>> _grouped(List<TaskWithCourse> entries) {
    final groups = <DateTime, List<TaskWithCourse>>{};
    for (final entry in entries) {
      final day = AppDate.dayOnly(entry.task.dueDate);
      groups.putIfAbsent(day, () => []).add(entry);
    }
    return groups;
  }

  Future<void> _toggle(TaskWithCourse entry, bool value) async {
    final id = entry.task.id;
    if (id == null) return;

    await setTaskCompleted(id, value);
    if (value) {
      await NotificationService.instance.cancelForTask(id);
    }
    if (mounted) context.read<DataRefresh>().bump();
  }

  Future<void> _openTask(TaskWithCourse entry) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          courseId: entry.course.id!,
          existingTask: entry.task,
          courseCode: entry.course.code,
        ),
      ),
    );
    if (saved == true && mounted) context.read<DataRefresh>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible();
    final groups = _grouped(visible);

    return Scaffold(
      body: SafeArea(
        child: PhoneFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Agenda',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                '${visible.length} task${visible.length == 1 ? '' : 's'} in view',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: compactDecoration(
                    context,
                    hint: 'Search tasks and courses…',
                    icon: Icons.search,
                    suffix: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...AgendaRange.values.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_rangeLabel(r)),
                          selected: _range == r,
                          onSelected: (_) => setState(() => _range = r),
                        ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Hide done'),
                      selected: _hideCompleted,
                      onSelected: (v) => setState(() => _hideCompleted = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(child: _body(groups)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Map<DateTime, List<TaskWithCourse>> groups) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load your agenda',
        message: _error,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available,
        title: 'Nothing scheduled',
        message: 'Add tasks to your courses and they will show up here.',
      );
    }

    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Nothing in this view',
        message: switch (_range) {
          AgendaRange.today => 'No tasks are due today.',
          AgendaRange.week => 'Nothing due in the next seven days.',
          AgendaRange.overdue => 'No overdue tasks — nicely done.',
          _ => 'Try a wider range or clear the search.',
        },
      );
    }

    final days = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: days.length,
        itemBuilder: (ctx, i) {
          final day = days[i];
          final entries = groups[day]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      _dayHeading(day),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _dayColor(day),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Divider(
                        color: AppSurfaces.of(context).outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entries.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...entries.map(
                (e) => TaskTile(
                  task: e.task,
                  course: e.course,
                  showCourse: true,
                  onToggle: (v) => _toggle(e, v),
                  onTap: () => _openTask(e),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dayHeading(DateTime day) {
    final today = AppDate.dayOnly(DateTime.now());
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff == -1) return 'YESTERDAY';
    if (diff < 0) return 'OVERDUE • ${AppDate.formatShortDate(day)}';
    return '${AppDate.formatWeekday(day).toUpperCase()} • '
        '${AppDate.formatShortDate(day)}';
  }

  Color _dayColor(DateTime day) {
    final today = AppDate.dayOnly(DateTime.now());
    if (day.isBefore(today)) return AppTheme.high;
    if (day == today) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _rangeLabel(AgendaRange range) => switch (range) {
    AgendaRange.today => 'Today',
    AgendaRange.week => 'Next 7 days',
    AgendaRange.upcoming => 'Upcoming',
    AgendaRange.overdue => 'Overdue',
    AgendaRange.all => 'All',
  };
}
