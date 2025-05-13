import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// 提醒服务类，用于管理用药提醒
class ReminderService {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final _uuid = const Uuid();
  
  List<Reminder> _reminders = [];
  List<MedicationRecord> _records = [];
  
  ReminderService({
    required StorageService storageService,
    required NotificationService notificationService,
  }) : _storageService = storageService,
       _notificationService = notificationService;
  
  /// 初始化服务
  Future<void> init() async {
    await loadData();
    await _notificationService.init();
    await _scheduleAllReminders();
    
    // 每分钟检查一次提醒
    // 计算到下一分钟0秒的时间差
    final now = DateTime.now();
    final secondsToNextMinute = 60 - now.second;
    Timer(Duration(seconds: secondsToNextMinute), () {
      // 每分钟0秒执行检查
      _scheduleAllReminders();
      // 设置每分钟一次的定时器
      Timer.periodic(const Duration(minutes: 1), (_) {
        _scheduleAllReminders();
      });
    });
  }
  
  /// 加载所有数据
  Future<void> loadData() async {
    _reminders = await _storageService.getReminders();
    _records = await _storageService.getMedicationRecords();
  }
  
  /// 获取所有提醒
  List<Reminder> get reminders => List.unmodifiable(_reminders);
  
  /// 获取所有服药记录
  List<MedicationRecord> get medicationRecords => List.unmodifiable(_records);

  /// 获取通知服务
  NotificationService get notificationService => _notificationService;
  
  /// 根据ID获取提醒
  Reminder? getReminderById(String id) {
    try {
      return _reminders.firstWhere((reminder) => reminder.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// 添加新的提醒
  Future<Reminder> addReminder({
    required String medicineName,
    required String dosage,
    required String unit,
    required List<DateTime> scheduledTimes,
    String notes = '',
  }) async {
    final reminder = Reminder(
      id: _uuid.v4(),
      medicineName: medicineName,
      dosage: dosage,
      unit: unit,
      scheduledTimes: scheduledTimes,
    );
    
    _reminders.add(reminder);
    await _saveReminders();
    await _scheduleReminder(reminder);
    
    return reminder;
  }
  
  /// 更新现有提醒
  Future<Reminder> updateReminder(Reminder updatedReminder) async {
    final index = _reminders.indexWhere((r) => r.id == updatedReminder.id);
    
    if (index == -1) {
      throw Exception('提醒不存在');
    }
    
    _reminders[index] = updatedReminder;
    await _saveReminders();
    await _notificationService.cancelNotification(updatedReminder.id);
    await _scheduleReminder(updatedReminder);
    
    return updatedReminder;
  }
  
  /// 删除提醒及其相关的服药记录
  Future<void> deleteReminder(String id) async {
    final reminder = getReminderById(id);
    print('开始删除提醒，ID: $id，药品名称: ${reminder?.medicineName}');
    final reminderCount = _reminders.length;
    final recordCount = _records.length;
    
    _reminders.removeWhere((reminder) => reminder.id == id);
    _records.removeWhere((record) => record.reminderId == id);
    
    print('删除后提醒数量: ${_reminders.length}，原数量: $reminderCount');
    print('删除后记录数量: ${_records.length}，原数量: $recordCount');
    
    await _saveReminders();
    await _saveMedicationRecords();
    await _notificationService.cancelNotification(id);
    print('删除操作完成，数据已保存');
  }
  
  /// 记录服药
  Future<MedicationRecord> recordMedication({
    required String reminderId,
    DateTime? takenAt,
    String notes = '',
  }) async {
    final reminder = getReminderById(reminderId);
    
    if (reminder == null) {
      throw Exception('提醒不存在');
    }
    
    final record = MedicationRecord(
      id: _uuid.v4(),
      reminderId: reminderId,
      medicineName: reminder.medicineName,
      dosage: reminder.dosage,
      unit: reminder.unit,
      takenAt: takenAt ?? DateTime.now(),
    );
    
    _records.add(record);
    await _saveMedicationRecords();
    
    return record;
  }
  
  /// 获取特定提醒的服药记录
  List<MedicationRecord> getMedicationRecordsForReminder(String reminderId){
    return _records.where((record) => record.reminderId == reminderId).toList();
  }
  
  /// 保存提醒列表到存储
  Future<void> _saveReminders() async {
    await _storageService.saveReminders(_reminders);
  }
  
  /// 保存服药记录到存储
  Future<void> _saveMedicationRecords() async {
    await _storageService.saveMedicationRecords(_records);
  }

  /// 调度所有提醒的通知
  Future<void> _scheduleAllReminders() async {
    for (final reminder in _reminders) {
      await _scheduleReminder(reminder);
    }
  }

  /// 检查并发送提醒通知
  Future<void> _scheduleReminder(Reminder reminder) async {
    final now = DateTime.now();
    print('当前时间: $now');
    for (final time in reminder.scheduledTimes) {
      print('提醒时间: $time');
      // 如果当前时间在预定时间的前后1分钟内，发送通知
      final difference = time.difference(now).inMinutes.abs();
      print('时间差: $difference');
      if (difference < 1) {
        print('发送通知: ${reminder.medicineName} ${reminder.dosage}${reminder.unit}');
        await _notificationService.scheduleReminder(
          id: reminder.id,
          title: '用药提醒',
          body: '该服用 ${reminder.medicineName} ${reminder.dosage}${reminder.unit} 了',
          scheduledTime: time,
        );
      }
    }
  }
}