import 'package:flutter/foundation.dart';

import '../core/agenda_range.dart';

/// Which bottom-navigation tab is showing, and one-shot deep-link state.
///
/// Owning the index in a provider (instead of MainShell's local state) lets any
/// screen switch tabs — the dashboard's "Overdue" card can jump straight to the
/// Agenda tab already filtered to overdue tasks.
class ShellTabs extends ChangeNotifier {
  static const home = 0;
  static const courses = 1;
  static const agenda = 2;
  static const stats = 3;
  static const ai = 4;

  int _index = home;
  AgendaRange? _pendingAgendaRange;

  int get index => _index;

  void go(int index, {AgendaRange? agendaRange}) {
    if (agendaRange != null) _pendingAgendaRange = agendaRange;
    if (_index == index && agendaRange == null) return;
    _index = index;
    notifyListeners();
  }

  /// Returns the requested agenda filter once, then clears it, so switching
  /// tabs by hand afterwards does not keep re-applying it.
  AgendaRange? takeAgendaRange() {
    final range = _pendingAgendaRange;
    _pendingAgendaRange = null;
    return range;
  }
}
