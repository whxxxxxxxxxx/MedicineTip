import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/constants.dart';

/// 通知服务类，用于管理应用的通知功能
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _hasPermission = false;

  /// 获取通知权限状态
  Future<bool> checkPermissionStatus() async {
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final status = await platform.areNotificationsEnabled();
      if (status != null) {
        _hasPermission = status;
        return _hasPermission;
      }
      return false;
    }
    return true;
  }

  /// 初始化通知服务
  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await _setupNotificationChannel();
    _isInitialized = true;
  }

  /// 设置通知渠道
  Future<void> _setupNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      AppConstants.reminderChannelId,
      AppConstants.reminderChannelName,
      description: AppConstants.reminderChannelDescription,
      importance: Importance.high,
    );

    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    // 处理iOS权限申请
    final iosPlatform = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlatform != null) {
      final result = await iosPlatform.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (result != null) {
        _hasPermission = result;
        return result;
      }
      return false;
    }
    
    // 处理Android权限申请
    final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      final result = await androidPlatform.requestNotificationsPermission();
      if (result != null) {
        _hasPermission = result;
        return result;
      }
      return false;
    }
    
    // 如果不是iOS或Android，默认返回true
    return true;
  }

  /// 发送用药提醒通知
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // 转换时间为本地时区
    final localTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    print('localTime: $localTime');
    print('now: $now');
    // 检查是否到达预定时间
    if (localTime.isBefore(now)) {
      return;
    }


    // 使用消息通知
    final androidDetails = AndroidNotificationDetails(
      AppConstants.reminderChannelId,
      AppConstants.reminderChannelName,
      channelDescription: AppConstants.reminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.message,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    await _notifications.show(
      id.hashCode,
      title,
      body,
      notificationDetails,
    );
  }

  /// 取消特定通知
  Future<void> cancelNotification(String id) async {
    await _notifications.cancel(id.hashCode);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}