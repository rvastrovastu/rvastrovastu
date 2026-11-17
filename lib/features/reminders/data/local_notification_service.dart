import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// One scheduled notification, already localized.
class NotificationRequest {
  final int id;
  final tz.TZDateTime at;
  final String title;
  final String body;
  final bool isDaily;

  const NotificationRequest({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.isDaily,
  });
}

/// Thin wrapper around flutter_local_notifications.
///
/// Uses inexact scheduling, so no exact-alarm permission is needed on
/// Android; reminders may arrive a few minutes late, which is fine for a
/// morning Panchang or an evening festival reminder.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _dailyChannel = AndroidNotificationDetails(
    'daily_panchang',
    'Daily Panchang',
    channelDescription: "Morning summary of the day's Panchang",
  );

  /// The daily channel, expanding to show every line of a multi-line
  /// body (the morning briefing).
  static AndroidNotificationDetails _daily(String title, String body) =>
      AndroidNotificationDetails(
        _dailyChannel.channelId,
        _dailyChannel.channelName,
        channelDescription: _dailyChannel.channelDescription,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );

  static const _festivalChannel = AndroidNotificationDetails(
    'festival_reminders',
    'Festival & vrat reminders',
    channelDescription: 'Reminders the evening before festivals and vrats',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Permission is requested only when the user turns reminders on.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Asks the OS for permission. Returns false if the user declines.
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }

    return false;
  }

  /// Replaces every pending notification with [requests].
  Future<void> replaceAll(List<NotificationRequest> requests) async {
    await _ensureInitialized();
    await _plugin.cancelAll();

    for (final request in requests) {
      await _plugin.zonedSchedule(
        id: request.id,
        scheduledDate: request.at,
        title: request.title,
        body: request.body,
        notificationDetails: NotificationDetails(
          android: request.isDaily
              ? _daily(request.title, request.body)
              : _festivalChannel,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
