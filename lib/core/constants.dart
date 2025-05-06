/// 应用常量定义文件

class AppConstants {
  // 应用名称
  static const String appName = "用药提醒"; 
  
  // 路由名称
  static const String homeRoute = "/";
  static const String addReminderRoute = "/add-reminder";
  static const String historyRoute = "/history";
  static const String settingsRoute = "/settings";
  static const String reminderDetailRoute = "/reminder-detail";
  
  // 本地存储键
  static const String remindersKey = "reminders";
  static const String settingsKey = "settings";
  
  // API相关
  static const String aliApiBaseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1";
  
  // 通知渠道
  static const String reminderChannelId = "reminder_channel";
  static const String reminderChannelName = "用药提醒通知";
  static const String reminderChannelDescription = "用于发送用药提醒的通知渠道";
}