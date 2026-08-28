import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import 'agenda_screen.dart';
import 'ai_assistant_screen.dart';
import 'courses_screen.dart';
import 'dashboard_screen.dart';
import 'statistics_screen.dart';

/// Bottom navigation host. Keeps every tab alive so scroll position and
/// filters survive tab switches.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    CoursesScreen(),
    AgendaScreen(),
    StatisticsScreen(),
    AiAssistantScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreReminders());
  }

  /// Scheduled notifications do not survive a reinstall or a permission
  /// change, so re-arm them for the signed-in account on start-up.
  Future<void> _restoreReminders() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    if (!settings.remindersEnabled || !auth.isAuthenticated) return;

    final service = NotificationService.instance;
    if (!service.isSupported) return;

    try {
      await service.rescheduleAllForUser(auth.userId);
    } catch (_) {
      // Reminders are best-effort; never block the UI on them.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Touch the refresh notifier so a data change anywhere rebuilds the shell
    // (and therefore the visible tab).
    context.watch<DataRefresh>();

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
