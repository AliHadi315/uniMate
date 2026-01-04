import 'package:flutter/material.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import '../models/course.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const blue = Color(0xFF2563EB);

  Future<Map<String, Object>> _loadStats() async {
    final courses = await loadCourses();

    final totalTasks = await countAllTasks();
    final completed = await countCompletedTasks();
    final pending = await countPendingTasks();
    final overdue = await countOverdueTasks();

    // Build progress per course
    final List<Map<String, Object>> perCourse = [];
    for (final c in courses) {
      if (c.id == null) continue;

      final tasks = await loadTasksByCourse(c.id!);
      final total = tasks.length;
      final done = tasks.where((t) => t.isCompleted == 1).length;

      perCourse.add({'course': c, 'total': total, 'done': done});
    }

    return {
      'totalTasks': totalTasks,
      'completed': completed,
      'pending': pending,
      'overdue': overdue,
      'perCourse': perCourse,
    };
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
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object>>(
        future: _loadStats(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data!;
          final totalTasks = data['totalTasks'] as int;
          final completed = data['completed'] as int;
          final pending = data['pending'] as int;
          final overdue = data['overdue'] as int;
          final perCourse = data['perCourse'] as List<Map<String, Object>>;

          final progress = totalTasks == 0 ? 0.0 : completed / totalTasks;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Track your progress',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _statTile(
                title: 'Total Tasks',
                value: totalTasks.toString(),
                icon: Icons.list_alt,
              ),
              _statTile(
                title: 'Completed Tasks',
                value: completed.toString(),
                icon: Icons.check_circle,
              ),
              _statTile(
                title: 'Pending Tasks',
                value: pending.toString(),
                icon: Icons.pending_actions,
              ),
              _statTile(
                title: 'Overdue Tasks',
                value: overdue.toString(),
                icon: Icons.warning,
              ),

              const SizedBox(height: 18),

              const Text(
                'Overall Progress',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(0)}% completed'),

              const SizedBox(height: 18),

              const Text(
                'Progress by Course',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (perCourse.isEmpty)
                const Text('No courses yet.')
              else
                ...perCourse.map((row) {
                  final course = row['course'] as Course;
                  final total = row['total'] as int;
                  final done = row['done'] as int;
                  final p = total == 0 ? 0.0 : done / total;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.name,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: p),
                          const SizedBox(height: 6),
                          Text('$done / $total completed'),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
