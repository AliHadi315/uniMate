import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Progress overview: totals, weekly activity, priority split and per-course
/// completion.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _CourseProgress {
  final Course course;
  final int total;
  final int done;
  final int overdue;

  const _CourseProgress({
    required this.course,
    required this.total,
    required this.done,
    required this.overdue,
  });

  double get ratio => total == 0 ? 0 : done / total;
}

class _StatsSnapshot {
  final int totalTasks;
  final int completed;
  final int pending;
  final int overdue;
  final List<int> weekly;
  final Map<String, int> byPriority;
  final List<_CourseProgress> perCourse;

  const _StatsSnapshot({
    required this.totalTasks,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.weekly,
    required this.byPriority,
    required this.perCourse,
  });

  double get progress => totalTasks == 0 ? 0 : completed / totalTasks;
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // The old version rebuilt this future inside build(), so every repaint hit
  // the database. It is now created once per data revision.
  late Future<_StatsSnapshot> _future;
  int _revision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = Provider.of<DataRefresh>(context).revision;
    if (revision != _revision) {
      _revision = revision;
      _future = _load();
    }
  }

  Future<_StatsSnapshot> _load() async {
    final userId = context.read<AuthProvider>().userId;
    final now = DateTime.now();

    final courses = await loadCourses(userId);
    final perCourse = <_CourseProgress>[];

    for (final course in courses) {
      final id = course.id;
      if (id == null) continue;
      final tasks = await loadTasksByCourse(id);
      perCourse.add(
        _CourseProgress(
          course: course,
          total: tasks.length,
          done: tasks.where((t) => t.completed).length,
          overdue: tasks
              .where((t) => !t.completed && t.dueDate.isBefore(now))
              .length,
        ),
      );
    }

    perCourse.sort((a, b) => a.ratio.compareTo(b.ratio));

    return _StatsSnapshot(
      totalTasks: await countAllTasks(userId),
      completed: await countCompletedTasks(userId),
      pending: await countPendingTasks(userId),
      overdue: await countOverdueTasks(userId),
      weekly: await completionsPerDay(userId),
      byPriority: await pendingByPriority(userId),
      perCourse: perCourse,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_StatsSnapshot>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load statistics',
              message: '${snap.error}',
              action: FilledButton(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            );
          }

          final data = snap.data!;
          if (data.totalTasks == 0) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No data yet',
              message: 'Add and complete a few tasks to see your progress.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _overallCard(data),
                const SizedBox(height: 16),
                _weeklyCard(data),
                const SizedBox(height: 16),
                _priorityCard(data),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Progress by course'),
                ...data.perCourse.map(_courseCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    final surfaces = AppSurfaces.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.outline),
      ),
      child: child,
    );
  }

  Widget _overallCard(_StatsSnapshot data) {
    final scheme = Theme.of(context).colorScheme;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Overall completion',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${(data.progress * 100).round()}%',
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
            child: LinearProgressIndicator(
              value: data.progress,
              minHeight: 10,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Total', data.totalTasks, scheme.primary),
              _miniStat('Done', data.completed, AppTheme.low),
              _miniStat('Open', data.pending, AppTheme.medium),
              _miniStat('Overdue', data.overdue, AppTheme.high),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyCard(_StatsSnapshot data) {
    final today = DateTime.now();
    final labels = List.generate(data.weekly.length, (i) {
      final day = today.subtract(Duration(days: data.weekly.length - 1 - i));
      return AppDate.formatWeekday(day).substring(0, 2);
    });
    final total = data.weekly.fold<int>(0, (a, b) => a + b);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tasks completed this week',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$total total',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MiniBarChart(values: data.weekly, labels: labels),
        ],
      ),
    );
  }

  Widget _priorityCard(_StatsSnapshot data) {
    final segments = [
      DonutSegment(
        label: 'High',
        value: data.byPriority['High'] ?? 0,
        color: AppTheme.high,
      ),
      DonutSegment(
        label: 'Medium',
        value: data.byPriority['Medium'] ?? 0,
        color: AppTheme.medium,
      ),
      DonutSegment(
        label: 'Low',
        value: data.byPriority['Low'] ?? 0,
        color: AppTheme.low,
      ),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open tasks by priority',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          DonutChart(segments: segments, centerLabel: 'open'),
        ],
      ),
    );
  }

  Widget _courseCard(_CourseProgress row) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTheme.courseColor(
      row.course.colorValue,
      seedIndex: row.course.id ?? 0,
    );

    return AppTile(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.course.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      row.course.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (row.overdue > 0)
                Pill(
                  text: '${row.overdue} overdue',
                  color: AppTheme.high,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: row.ratio,
              minHeight: 7,
              color: accent,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            row.total == 0
                ? 'No tasks yet'
                : '${row.done} / ${row.total} completed '
                      '(${(row.ratio * 100).round()}%)',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
