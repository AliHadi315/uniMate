import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../db/task_storage.dart';
import '../models/task.dart';

/// Schedules local reminders for tasks.
///
/// Every method is defensive: notifications are a nice-to-have, so a platform
/// that cannot deliver them (desktop, denied permission, missing plugin) must
/// never break saving a task.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _supported = false;

  /// True when this platform can actually show reminders.
  bool get isSupported => _supported;

  static const _channelId = 'unimate_task_reminders';
  static const _channelName = 'Task reminders';
  static const _channelDescription = 'Reminders for upcoming coursework';

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // The plugin only implements Android, iOS and macOS.
    _supported = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    if (!_supported) return;

    try {
      tz_data.initializeTimeZones();
      // `identifier` is the IANA name (e.g. Europe/Berlin) that the timezone
      // database expects.
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('Falling back to UTC for reminders: $e');
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
      );
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      _supported = false;
    }
  }

  /// Asks for permission where the platform requires it. Returns whether
  /// reminders can be delivered.
  Future<bool> requestPermissions() async {
    if (!_supported) return false;

    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }

      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await darwin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    } catch (e) {
      debugPrint('Could not request notification permission: $e');
      return false;
    }
  }

  /// Notification ids are derived from the task id so rescheduling replaces
  /// the previous reminder instead of stacking duplicates.
  int _idFor(int taskId) => taskId % 0x7FFFFFFF;

  /// (Re)schedules the reminder for [task]. Cancels it when the task has no
  /// reminder, is completed, or the reminder time has already passed.
  Future<void> scheduleForTask(Task task, {required String courseCode}) async {
    final id = task.id;
    if (id == null) return;
    if (!_supported) return;

    await cancelForTask(id);

    if (task.completed) return;
    final when = task.reminderTime;
    if (when == null || !when.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: _idFor(id),
        title: '${task.type}: ${task.title}',
        body: '$courseCode • due ${_shortWhen(task.dueDate)}',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:$id',
      );
    } catch (e) {
      debugPrint('Could not schedule reminder for task $id: $e');
    }
  }

  /// Re-arms every pending reminder for [userId]. Scheduled notifications are
  /// lost on reinstall or when permission is re-granted, so this runs on start.
  Future<void> rescheduleAllForUser(int userId) async {
    if (!_supported || userId < 0) return;

    await cancelAll();
    final pending = await loadTasksWithReminders(userId);
    for (final entry in pending) {
      await scheduleForTask(entry.task, courseCode: entry.course.code);
    }
  }

  Future<void> cancelForTask(int taskId) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: _idFor(taskId));
    } catch (e) {
      debugPrint('Could not cancel reminder for task $taskId: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }

  String _shortWhen(DateTime due) {
    final h = due.hour.toString().padLeft(2, '0');
    final m = due.minute.toString().padLeft(2, '0');
    return '${due.day}/${due.month} $h:$m';
  }
}
