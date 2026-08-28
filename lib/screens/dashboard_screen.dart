import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'course_details_screen.dart';
import 'settings_screen.dart';
import 'task_form_screen.dart';

/// Overview screen: at-a-glance counters, progress and what is due next.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardSnapshot {
  final int courses;
  final int totalTasks;
  final int completed;
  final int pending;
  final int overdue;
  final int dueToday;
  final List<TaskWithCourse> upcoming;
  final List<TaskWithCourse> overdueTasks;

  const _DashboardSnapshot({
    required this.courses,
    required this.totalTasks,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.upcoming,
    required this.overdueTasks,
  });

  double get progress => totalTasks == 0 ? 0 : completed / totalTasks;
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardSnapshot> _future;
  int _revision = -1;

  Future<_DashboardSnapshot> _load() async {
    final userId = context.read<AuthProvider>().userId;

    final results = await Future.wait([
      countCourses(userId),
      countAllTasks(userId),
      countCompletedTasks(userId),
      countPendingTasks(userId),
      countOverdueTasks(userId),
      countDueTodayTasks(userId),
    ]);

    final upcoming = await loadUpcomingTasks(userId, limit: 5);
    final overdueTasks = await loadOverdueTasks(userId, limit: 3);

    return _DashboardSnapshot(
      courses: results[0],
      totalTasks: results[1],
      completed: results[2],
      pending: results[3],
      overdue: results[4],
      dueToday: results[5],
      upcoming: upcoming,
      overdueTasks: overdueTasks,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload whenever any screen reports a data change.
    final revision = Provider.of<DataRefresh>(context).revision;
    if (revision != _revision) {
      _revision = revision;
      _future = _load();
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openTask(TaskWithCourse entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          courseId: entry.course.id!,
          existingTask: entry.task,
          courseCode: entry.course.code,
        ),
      ),
    );
    if (mounted) context.read<DataRefresh>().bump();
  }

  Future<void> _toggle(TaskWithCourse entry, bool value) async {
    await setTaskCompleted(entry.task.id!, value);
    if (mounted) context.read<DataRefresh>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            Text(
              user?.fullName ?? 'UniMate',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Tooltip(
                message: 'Profile & settings',
                child: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    user?.initials ?? '?',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_DashboardSnapshot>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load your dashboard',
              message: '${snap.error}',
              action: FilledButton(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            );
          }

          final data = snap.data!;

          if (data.courses == 0) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: 'Welcome to UniMate',
              message:
                  'Add your first course from the Courses tab, then start '
                  'tracking assignments, exams and resources.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _statGrid(data),
                const SizedBox(height: 18),
                _progressCard(data),
                const SizedBox(height: 18),

                if (data.overdueTasks.isNotEmpty) ...[
                  const SectionHeader(title: 'Needs attention'),
                  ...data.overdueTasks.map(
                    (e) => TaskTile(
                      task: e.task,
                      course: e.course,
                      showCourse: true,
                      onToggle: (v) => _toggle(e, v),
                      onTap: () => _openTask(e),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SectionHeader(
                  title: 'Upcoming',
                  trailing: Text(
                    '${data.dueToday} due today',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (data.upcoming.isEmpty)
                  AppTile(
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.low,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Nothing due — you are all caught up.'),
                        ),
                      ],
                    ),
                  )
                else
                  ...data.upcoming.map(
                    (e) => TaskTile(
                      task: e.task,
                      course: e.course,
                      showCourse: true,
                      onToggle: (v) => _toggle(e, v),
                      onTap: () => _openTask(e),
                    ),
                  ),

                const SizedBox(height: 8),
                if (data.upcoming.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailsScreen(
                            course: data.upcoming.first.course,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        'Open ${data.upcoming.first.course.code}',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statGrid(_DashboardSnapshot data) {
    final items = [
      _Stat('Courses', data.courses, Icons.school, AppTheme.seed),
      _Stat('Due today', data.dueToday, Icons.today, AppTheme.medium),
      _Stat('Overdue', data.overdue, Icons.warning_amber, AppTheme.high),
      _Stat('Completed', data.completed, Icons.check_circle, AppTheme.low),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, four on wide windows.
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((s) => SizedBox(width: width, child: _statCard(s)))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(_Stat stat) {
    final surfaces = AppSurfaces.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(stat.icon, size: 18, color: stat.color),
          ),
          const SizedBox(height: 10),
          Text(
            '${stat.value}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(_DashboardSnapshot data) {
    final surfaces = AppSurfaces.of(context);
    final scheme = Theme.of(context).colorScheme;
    final percent = (data.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Overall progress',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: data.progress),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${data.completed} of ${data.totalTasks} tasks done • '
            '${data.pending} upcoming • ${data.overdue} overdue',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return '$part • ${AppDate.formatDate(DateTime.now())}';
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _Stat(this.label, this.value, this.icon, this.color);
}
