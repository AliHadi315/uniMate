import 'package:flutter/foundation.dart';

/// Broadcasts "the stored data changed" so screens kept alive by the
/// bottom-navigation [IndexedStack] reload instead of showing stale numbers.
///
/// Screens watch [revision] and rebuild their futures when it changes; any
/// code that writes to the database calls [bump].
class DataRefresh extends ChangeNotifier {
  int _revision = 0;

  int get revision => _revision;

  void bump() {
    _revision++;
    notifyListeners();
  }
}
