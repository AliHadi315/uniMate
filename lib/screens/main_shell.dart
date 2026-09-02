import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../providers/settings_provider.dart';
import '../providers/shell_tabs.dart';
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
      // Android 13+ will silently drop every reminder until POST_NOTIFICATIONS
      // is granted. Reminders are on by default, so ask here rather than only
      // when the user happens to visit Settings.
      await service.requestPermissions();
      await service.rescheduleAllForUser(auth.userId);

      // The repeating daily check-in is cancelled by rescheduleAllForUser's
      // cancelAll, so re-arm it when the user has it enabled.
      if (settings.dailySummaryEnabled) {
        await service.scheduleDailySummary(
          hour: settings.dailySummaryMinutes ~/ 60,
          minute: settings.dailySummaryMinutes % 60,
        );
      }
    } catch (_) {
      // Reminders are best-effort; never block the UI on them.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Touch the refresh notifier so a data change anywhere rebuilds the shell
    // (and therefore the visible tab).
    context.watch<DataRefresh>();

    // The tab index lives in a provider so any screen can deep-link to a tab
    // (e.g. dashboard stat cards jumping to a pre-filtered Agenda).
    final tabs = context.watch<ShellTabs>();

    return Scaffold(
      body: IndexedStack(index: tabs.index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.index,
        onDestinationSelected: tabs.go,
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
