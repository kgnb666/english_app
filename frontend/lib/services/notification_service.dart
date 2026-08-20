import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_timezone/flutter_timezone.dart";
import "package:timezone/data/latest.dart" as tzdata;
import "package:timezone/timezone.dart" as tz;

/// 本地通知服务：初始化、权限申请、每日学习提醒
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const String _channelId = "daily_reminder";
  static const String _channelName = "每日学习提醒";
  static const String _channelDesc = "每天定时提醒完成英语学习任务";

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 冷启动时由通知点击带入的跳转路由
  String? launchRoute;

  bool get isInitialized => _initialized;

  /// App 启动时调用
  Future<void> init({void Function(String route)? onNotificationTap}) async {
    if (_initialized) return;

    // 初始化时区（zonedSchedule 依赖）
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint("NotificationService timezone error: $e");
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings("@mipmap/ic_launcher");
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final route = (response.payload != null && response.payload!.isNotEmpty)
            ? response.payload!
            : "/home";
        onNotificationTap?.call(route);
      },
    );

    // 冷启动：由通知点击拉起 App 时记录目标路由
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload;
        launchRoute = (payload != null && payload.isNotEmpty) ? payload : "/home";
      }
    } catch (e) {
      debugPrint("NotificationService launch details error: $e");
    }

    _initialized = true;
  }

  /// 申请通知权限（Android 13+ 运行时通知权限、Android 12+ 精确闹钟）
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? true;
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint("NotificationService exact alarm permission error: $e");
    }
    return granted;
  }

  /// 设置每日定时提醒；enabled 为 false 时取消
  Future<void> scheduleDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await cancelDailyReminder();
    if (!enabled) return;

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    final scheduledAt = tz.TZDateTime.from(next, tz.local);
    await _plugin.zonedSchedule(
      _dailyReminderId,
      "英语学习提醒",
      "今天还有英语学习任务，快来打卡吧！",
      scheduledAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload ?? "/vocabulary",
    );
  }

  /// 取消每日提醒
  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(_dailyReminderId);
    } catch (e) {
      debugPrint("NotificationService cancel error: $e");
    }
  }
}
