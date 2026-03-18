import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../../features/notes/domain/models/note.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` before using other Firebase services.
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Callback that the service invokes when a notification action is tapped.
/// [actionId] is 'check_off' or 'snooze', [noteId] is the task ID.
typedef NotificationActionCallback =
    Future<void> Function(String actionId, String noteId);

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
        AndroidInitializationSettings('ic_notification_synq');

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

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
    } catch (e) {
      debugPrint(
        '⚠️ [NotificationService] Failed to initialize with custom icon, falling back: $e',
      );
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: initializationSettingsDarwin,
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Foreground message received: ${message.messageId}',
        );
      }
    });
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (kDebugMode) {
      debugPrint('[NotificationService] Notification action: $actionId');
    }

    if (actionId != null &&
        actionId.isNotEmpty &&
        payload != null &&
        payload.isNotEmpty) {
      if (onAction != null) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Routing action to handler');
        }
        await onAction!(actionId, payload);
      } else {
        if (kDebugMode) {
          debugPrint('[NotificationService] onAction handler is null');
        }
      }
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return;
      }

      if (defaultTargetPlatform != TargetPlatform.android) {
        return;
      }

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation == null) {
        debugPrint(
          '[NotificationService] Android notification implementation is unavailable.',
        );
        return;
      }

      // Android 13+ (API 33+) requires permission for POST_NOTIFICATIONS
      await androidImplementation.requestNotificationsPermission();

      // Android 12+ (API 31+) requires permission for exact alarms
      await androidImplementation.requestExactAlarmsPermission();

      // FCM Permissions
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('[NotificationService] Failed to request permissions: $e');
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
        icon: 'ic_notification_synq',
        largeIcon: const DrawableResourceAndroidBitmap('ic_large_notification'),
        color: const Color(0xFF00B0FF), // Electric blue branding
        // Rich text
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
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

      bool canScheduleExact = true;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        canScheduleExact =
            await androidImplementation?.canScheduleExactNotifications() ??
            false;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: noteId,
      );

      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Notification scheduled successfully.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Error scheduling notification: $e');
      }
    }
  }

  /// Centralized logic to schedule or cancel notifications for a Note
  Future<void> scheduleNote(Note note) async {
    final notifId = note.id.hashCode;

    // Always cancel first to avoid duplicates
    await cancelNotification(notifId);

    // Don't schedule for completed tasks
    if (note.isCompleted) return;

    final now = DateTime.now();
    DateTime? notifyTime;
    String bodyText = note.body ?? 'Task reminder';
    if (note.reminderTime != null) {
      notifyTime = note.reminderTime;
      bodyText =
          '${note.body ?? "Reminder"} · Due ${_formatTime(note.scheduledTime)}';
    } else if (note.scheduledTime != null) {
      if (note.isAllDay) {
        // Default to 9:00 AM on the scheduled date for all-day tasks
        notifyTime = DateTime(
          note.scheduledTime!.year,
          note.scheduledTime!.month,
          note.scheduledTime!.day,
          9,
          0,
        );
        bodyText = note.body ?? 'All day task';
      } else {
        notifyTime = note.scheduledTime;
        bodyText =
            '${note.body ?? "Task starting now"} · ${_formatTime(note.scheduledTime)}';
      }
    }

    if (notifyTime != null && notifyTime.isAfter(now)) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Scheduling notification for task id ${note.id}',
        );
      }
      await scheduleNotification(
        id: notifId,
        title: note.title,
        body: bodyText,
        scheduledDate: notifyTime,
        noteId: note.id,
      );
    } else if (notifyTime != null) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Notify time is in the past, skipping.',
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] Task has no specific notification time.',
        );
      }
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'No time set';
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
