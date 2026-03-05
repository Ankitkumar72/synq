import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Callback that the service invokes when a notification action is tapped.
/// [actionId] is `'check_off'` or `'snooze'`, [noteId] is the task ID.
typedef NotificationActionCallback = Future<void> Function(
    String actionId, String noteId);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// External callback set by the app (notes_provider) to handle actions.
  NotificationActionCallback? onAction;

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_synq');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  Future<void> _handleNotificationResponse(
      NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (actionId != null &&
        actionId.isNotEmpty &&
        payload != null &&
        payload.isNotEmpty) {
      if (onAction != null) {
        await onAction!(actionId, payload);
      }
    }
    // Tapping the notification body (no actionId) can be handled here
    // for navigation in the future.
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Schedule a rich notification with action buttons.
  ///
  /// [subText] is shown as the header line, e.g. "Synq Task • Due Now".
  /// [noteId] is stored as the payload so actions know which task to operate on.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String subText = 'Synq Task • Due Now',
    String? noteId,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'synq_task_channel',
        'Synq Tasks',
        channelDescription: 'Notifications for scheduled tasks and reminders',
        importance: Importance.max,
        priority: Priority.high,
        // Icon setup
        icon: 'ic_stat_synq',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        // Rich text
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: subText,
        ),
        subText: subText,
        // Action buttons
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'check_off',
            '✓ Check Off',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze 10m',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: noteId,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
