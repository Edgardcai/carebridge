import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import 'integration_ports.dart';

class LocalNotificationPort implements NotificationPort {
  LocalNotificationPort({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Call from [main] before [runApp] so the native plugin is wired before scheduling.
  Future<void> initialize() async {
    if (_initialized) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: settings));
    tz.initializeTimeZones();
    _initialized = true;
  }

  @override
  Future<void> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    debugPrint('CareBridge notifications: permission requested');
  }

  tz.TZDateTime _instantAsUtcTz(DateTime localWallClock) =>
      tz.TZDateTime.from(localWallClock.toUtc(), tz.UTC);

  Future<void> _zonedScheduleCompat({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime zonedFireTime,
    required NotificationDetails details,
  }) async {
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          zonedFireTime,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

    try {
      debugPrint('CareBridge notifications: schedule exact at $zonedFireTime');
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e, st) {
      debugPrint(
        'CareBridge: exactAllowWhileIdle schedule failed ($e). Retrying inexact. $st',
      );
      debugPrint('CareBridge notifications: schedule inexact at $zonedFireTime');
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> scheduleTaskReminder(CareTask task) async {
    await requestPermission();
    if (task.status != TaskStatus.pending) return;

    final now = DateTime.now();
    var reminderTime =
        task.scheduledAt.subtract(Duration(minutes: task.remindMinutesBefore));

    if (reminderTime.isBefore(now) && task.scheduledAt.isAfter(now)) {
      reminderTime = task.scheduledAt;
    }

    final taskMomentPast = task.scheduledAt.toUtc().isBefore(now.toUtc());
    var fireAt = reminderTime;

    // Fire at-least-soon ahead so "now-ish" reminders are not discarded by rounding.
    if (!fireAt.isAfter(now)) {
      if (taskMomentPast) {
        return;
      }
      fireAt = now.add(const Duration(seconds: 3));
    }

    await _zonedScheduleCompat(
      id: _notificationId(task.id),
      title: task.title,
      body: task.details.isEmpty ? 'CareBridge reminder' : task.details,
      zonedFireTime: _instantAsUtcTz(fireAt),
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'carebridge_task_reminders',
          'Task reminders',
          channelDescription: 'Reminder notifications for care tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint(
      'CareBridge notifications: pending=${pending.length}, latestTask=${task.id}, fireAt=$fireAt',
    );
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    await initialize();
    await _plugin.cancel(_notificationId(taskId));
  }

  @override
  Future<void> rescheduleAll(List<CareTask> tasks) async {
    await initialize();
    await _plugin.cancelAll();
    for (final task in tasks) {
      await scheduleTaskReminder(task);
    }
  }

  /// Quick manual check from Settings debug flow.
  Future<void> scheduleTestPingIn(Duration delay) async {
    await requestPermission();
    final fireAt = DateTime.now().add(delay);
    await _zonedScheduleCompat(
      id: 91919191,
      title: 'CareBridge test reminder',
      body: 'Local notifications are working.',
      zonedFireTime: _instantAsUtcTz(fireAt),
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'carebridge_task_reminders',
          'Task reminders',
          channelDescription: 'Reminder notifications for care tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('CareBridge notifications: test scheduled, pending=${pending.length}');
  }

  Future<void> showInstantTest() async {
    await requestPermission();
    await _plugin.show(
      91919192,
      'CareBridge instant test',
      'If you can see this, notification plugin works.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'carebridge_task_reminders',
          'Task reminders',
          channelDescription: 'Reminder notifications for care tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    debugPrint('CareBridge notifications: instant test shown');
  }

  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;
}
