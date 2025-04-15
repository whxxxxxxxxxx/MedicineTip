import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import 'storage_service.dart';

/// 提醒服务类，用于管理用药提醒
class ReminderService {
  final StorageService _storageService;
  final _uuid = const Uuid();
  
  List<Reminder> _reminders = [];
  List<MedicationRecord> _records = [];
  
  ReminderService({
    required StorageService storageService,
  }) : _storageService = storageService;
  
  /// 初始化服务
  Future<void> init() async {
    await loadData();
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
}