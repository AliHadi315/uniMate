import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import '../models/task.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, Object>> _loadDashboard() async {
    final courses = await loadCourses();
    final totalCourses = courses.length;

    final totalTasks = await countAllTasks();
    final completed = await countCompletedTasks();
    final pending = await countPendingTasks();
    final overdue = await countOverdueTasks();

    final upcoming = await loadUpcomingTasks(limit: 5);

    return {
      'totalCourses': totalCourses,
      'totalTasks': totalTasks,
      'completed': completed,
      'pending': pending,
      'overdue': overdue,
      'upcoming': upcoming,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),

          // Profile/Login goes here
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isAuthenticated) {
                return PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'logout') auth.logout();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'user',
                      child: Text(auth.currentUser!.fullName),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'logout', child: Text('Logout')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: CircleAvatar(
                      child: Text(
                        auth.currentUser!.fullName.isNotEmpty
                            ? auth.currentUser!.fullName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                  ),
                );
              }

              return IconButton(
                tooltip: 'Login',
                icon: const Icon(Icons.person),
                onPressed: () => Navigator.of(context).pushNamed('/login'),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object>>(
        future: _loadDashboard(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data!;
          final totalCourses = data['totalCourses'] as int;
          final totalTasks = data['totalTasks'] as int;
          final completed = data['completed'] as int;
          final pending = data['pending'] as int;
          final overdue = data['overdue'] as int;
          final upcoming = data['upcoming'] as List<Task>;

          final progress = totalTasks == 0 ? 0.0 : completed / totalTasks;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard('Courses', totalCourses.toString(), Icons.school),
                  _statCard(
                    'Total Tasks',
                    totalTasks.toString(),
                    Icons.list_alt,
                  ),
                  _statCard(
                    'Completed',
                    completed.toString(),
                    Icons.check_circle,
                  ),
                  _statCard(
                    'Pending',
                    pending.toString(),
                    Icons.pending_actions,
                  ),
                  _statCard('Overdue', overdue.toString(), Icons.warning),
                ],
              ),

              const SizedBox(height: 18),

              const Text(
                'Overall Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(0)}% completed'),

              const SizedBox(height: 18),

              const Text(
                'Upcoming Tasks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (upcoming.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No upcoming tasks.'),
                  ),
                )
              else
                ...upcoming.map((t) {
                  final due = DateTime.fromMillisecondsSinceEpoch(
                    t.dueDateMillis,
                  );
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(t.title),
                      subtitle: Text(
                        '${t.type} • ${t.priority}\nDue: ${due.day}/${due.month}/${due.year}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
