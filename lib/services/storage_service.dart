import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../core/constants.dart';

/// 存储服务类，用于管理应用数据的本地存储
class StorageService {
  late SharedPreferences _prefs;
  
  /// 初始化存储服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 保存提醒列表
  Future<bool> saveReminders(List<Reminder> reminders) async {
    final List<String> reminderJsonList = reminders
        .map((reminder) => jsonEncode(reminder.toJson()))
        .toList();
    return await _prefs.setStringList(AppConstants.remindersKey, reminderJsonList);
  }
  
  /// 获取所有提醒
  Future<List<Reminder>> getReminders() async {
    final List<String>? reminderJsonList = _prefs.getStringList(AppConstants.remindersKey);
    
    if (reminderJsonList == null || reminderJsonList.isEmpty) {
      return [];
    }
    
    return reminderJsonList
        .map((reminderJson) => Reminder.fromJson(jsonDecode(reminderJson)))
        .toList();
  }
  
  /// 保存服药记录
  Future<bool> saveMedicationRecords(List<MedicationRecord> records) async {
    final List<String> recordJsonList = records
        .map((record) => jsonEncode(record.toJson()))
        .toList();
    return await _prefs.setStringList('medication_records', recordJsonList);
  }
  
  /// 获取所有服药记录
  Future<List<MedicationRecord>> getMedicationRecords() async {
    final List<String>? recordJsonList = _prefs.getStringList('medication_records');
    
    if (recordJsonList == null || recordJsonList.isEmpty) {
      return [];
    }
    
    return recordJsonList
        .map((recordJson) => MedicationRecord.fromJson(jsonDecode(recordJson)))
        .toList();
  }
  
  /// 根据提醒ID获取相关的服药记录
  Future<List<MedicationRecord>> getMedicationRecordsByReminderId(String reminderId) async {
    final List<MedicationRecord> allRecords = await getMedicationRecords();
    return allRecords.where((record) => record.reminderId == reminderId).toList();
  }
  
  /// 保存应用设置
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    return await _prefs.setString(AppConstants.settingsKey, jsonEncode(settings));
  }
  
  /// 获取应用设置
  Future<Map<String, dynamic>> getSettings() async {
    final String? settingsJson = _prefs.getString(AppConstants.settingsKey);
    
    if (settingsJson == null || settingsJson.isEmpty) {
      return {}; // 返回默认设置
    }
    
    return jsonDecode(settingsJson) as Map<String, dynamic>;
  }
  
  /// 清除所有数据（用于测试或重置应用）
  Future<bool> clearAll() async {
    return await _prefs.clear();
  }
}