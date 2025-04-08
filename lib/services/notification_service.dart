import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/reminder.dart';
import '../core/constants.dart';

/// 通知服务类，用于管理应用的本地通知
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> init() async {
    if (_isInitialized) return;
    
    // 初始化时区数据
    tz_data.initializeTimeZones();
    
    // 初始化通知插件
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // 创建通知渠道（仅Android需要）
    await _createNotificationChannel();
    
    _isInitialized = true;
  }
  
  /// 创建通知渠道
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      AppConstants.reminderChannelId,
      AppConstants.reminderChannelName,
      description: AppConstants.reminderChannelDescription,
      importance: Importance.high,
    );
    
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// 处理通知点击事件
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: 处理通知点击，例如导航到特定页面
    print('通知被点击: ${response.payload}');
  }
  
  /// 为提醒设置通知
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (!_isInitialized) await init();
    
    // 取消该提醒的所有现有通知
    await cancelReminderNotifications(reminder.id);
    
    // 如果提醒未激活，则不设置新通知
    if (!reminder.isActive) return;
    
    // 为每个计划时间设置通知
    for (int i = 0; i < reminder.scheduledTimes.length; i++) {
      final scheduledTime = reminder.scheduledTimes[i];
      
      // 如果时间已过，则跳过
      if (scheduledTime.isBefore(DateTime.now())) continue;
      
      final notificationId = '${reminder.id}_$i'.hashCode;
      
      final androidDetails = AndroidNotificationDetails(
        AppConstants.reminderChannelId,
        AppConstants.reminderChannelName,
        channelDescription: AppConstants.reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ticker: '用药提醒',
      );
      
      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '用药提醒',
        '该服用${reminder.medicineName}了，剂量：${reminder.dosage}${reminder.unit}',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    }
  }
  
  /// 取消特定提醒的所有通知
  Future<void> cancelReminderNotifications(String reminderId) async {
    if (!_isInitialized) await init();
    
    // 由于我们无法直接按组取消通知，这里使用一个简单的方法：
    // 为每个提醒预留100个通知ID的空间
    final baseId = reminderId.hashCode;
    for (int i = 0; i < 100; i++) {
      await _notificationsPlugin.cancel(baseId + i);
    }
  }
  
  /// 发送即时通知
  Future<void> showInstantNotification(String title, String body, {String? payload}) async {
    if (!_isInitialized) await init();
    
    final androidDetails = AndroidNotificationDetails(
      AppConstants.reminderChannelId,
      AppConstants.reminderChannelName,
      channelDescription: AppConstants.reminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const BigTextStyleInformation(''), // 使用 BigTextStyle 替代
      ticker: '用药提醒',
    );
    
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
  
  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await init();
    await _notificationsPlugin.cancelAll();
  }
}