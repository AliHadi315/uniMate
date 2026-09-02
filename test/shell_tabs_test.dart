import 'package:flutter_test/flutter_test.dart';
import 'package:unimate/core/agenda_range.dart';
import 'package:unimate/providers/shell_tabs.dart';

void main() {
  group('ShellTabs', () {
    test('go switches the tab and notifies', () {
      final tabs = ShellTabs();
      var notified = 0;
      tabs.addListener(() => notified++);

      tabs.go(ShellTabs.agenda);

      expect(tabs.index, ShellTabs.agenda);
      expect(notified, 1);
    });

    test('re-selecting the same tab without a filter does not notify', () {
      final tabs = ShellTabs();
      var notified = 0;
      tabs.addListener(() => notified++);

      tabs.go(ShellTabs.home);

      expect(notified, 0);
    });

    test('an agenda filter is delivered exactly once', () {
      final tabs = ShellTabs();

      tabs.go(ShellTabs.agenda, agendaRange: AgendaRange.overdue);

      expect(tabs.takeAgendaRange(), AgendaRange.overdue);
      // Consumed: switching tabs by hand later must not re-apply it.
      expect(tabs.takeAgendaRange(), isNull);
    });

    test('a filter for the already-visible agenda still notifies', () {
      final tabs = ShellTabs()..go(ShellTabs.agenda);
      var notified = 0;
      tabs.addListener(() => notified++);

      tabs.go(ShellTabs.agenda, agendaRange: AgendaRange.today);

      expect(notified, 1);
      expect(tabs.takeAgendaRange(), AgendaRange.today);
    });
  });
}
