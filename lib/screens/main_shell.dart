import 'package:flutter/material.dart';
import '../models/course.dart';
import 'dashboard_screen.dart';
import 'courses_screen.dart';
import 'statistics_screen.dart';
import 'ai_assistant_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.initialCourses});
  final List<Course> initialCourses;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      CoursesScreen(courses: widget.initialCourses),
      const StatisticsScreen(),
      const AiAssistantScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
