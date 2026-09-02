import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences that survive restarts: theme and reminder opt-in.
class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'unimate.settings.themeMode';
  static const _remindersKey = 'unimate.settings.remindersEnabled';
  static const _defaultReminderKey = 'unimate.settings.defaultReminderMinutes';
  static const _dailySummaryKey = 'unimate.settings.dailySummaryEnabled';
  static const _dailySummaryMinutesKey =
      'unimate.settings.dailySummaryMinutes';

  ThemeMode _themeMode = ThemeMode.system;
  bool _remindersEnabled = true;
  int _defaultReminderMinutes = 60;
  bool _dailySummaryEnabled = false;

  /// Minutes since midnight for the daily check-in. Defaults to 08:00.
  int _dailySummaryMinutes = 8 * 60;

  ThemeMode get themeMode => _themeMode;
  bool get remindersEnabled => _remindersEnabled;
  int get defaultReminderMinutes => _defaultReminderMinutes;
  bool get dailySummaryEnabled => _dailySummaryEnabled;
  int get dailySummaryMinutes => _dailySummaryMinutes;
  TimeOfDay get dailySummaryTime => TimeOfDay(
    hour: _dailySummaryMinutes ~/ 60,
    minute: _dailySummaryMinutes % 60,
  );

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey);
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _remindersEnabled = prefs.getBool(_remindersKey) ?? true;
      _defaultReminderMinutes = prefs.getInt(_defaultReminderKey) ?? 60;
      _dailySummaryEnabled = prefs.getBool(_dailySummaryKey) ?? false;
      _dailySummaryMinutes = prefs.getInt(_dailySummaryMinutesKey) ?? 8 * 60;
    } catch (e) {
      debugPrint('Could not load settings: $e');
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _write((prefs) => prefs.setString(_themeKey, mode.name));
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    _remindersEnabled = enabled;
    notifyListeners();
    await _write((prefs) => prefs.setBool(_remindersKey, enabled));
  }

  Future<void> setDefaultReminderMinutes(int minutes) async {
    _defaultReminderMinutes = minutes;
    notifyListeners();
    await _write((prefs) => prefs.setInt(_defaultReminderKey, minutes));
  }

  Future<void> setDailySummaryEnabled(bool enabled) async {
    _dailySummaryEnabled = enabled;
    notifyListeners();
    await _write((prefs) => prefs.setBool(_dailySummaryKey, enabled));
  }

  Future<void> setDailySummaryMinutes(int minutes) async {
    _dailySummaryMinutes = minutes;
    notifyListeners();
    await _write((prefs) => prefs.setInt(_dailySummaryMinutesKey, minutes));
  }

  Future<void> _write(Future<void> Function(SharedPreferences) action) async {
    try {
      await action(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }
}
