import 'package:flutter/foundation.dart';

/// 用药提醒模型类
class Reminder {
  final String id;
  final String medicineName; // 药品名称
  final String dosage; // 剂量
  final String unit; // 单位（如：片、毫升等）
  final List<DateTime> scheduledTimes; // 计划服药时间
  final String notes; // 备注
  final bool isActive; // 是否激活提醒
  final DateTime createdAt; // 创建时间
  final DateTime? lastTakenAt; // 最后一次服药时间
  final DateTime time;

  Reminder({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.unit,
    required this.scheduledTimes,
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    this.lastTakenAt,
    required this.time,
  });

  /// 从JSON创建Reminder对象
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      medicineName: json['medicineName'],
      dosage: json['dosage'],
      unit: json['unit'],
      scheduledTimes: (json['scheduledTimes'] as List)
          .map((time) => DateTime.parse(time))
          .toList(),
      notes: json['notes'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      lastTakenAt: json['lastTakenAt'] != null
          ? DateTime.parse(json['lastTakenAt'])
          : null,
      time: DateTime.parse(json['time']),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineName': medicineName,
      'dosage': dosage,
      'unit': unit,
      'scheduledTimes':
          scheduledTimes.map((time) => time.toIso8601String()).toList(),
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastTakenAt': lastTakenAt?.toIso8601String(),
    };
  }

  /// 创建Reminder的副本并更新指定字段
  Reminder copyWith({
    String? id,
    String? medicineName,
    String? dosage,
    String? unit,
    List<DateTime>? scheduledTimes,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    ValueGetter<DateTime?>? lastTakenAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastTakenAt: lastTakenAt != null ? lastTakenAt() : this.lastTakenAt,
      time: time,
    );
  }
}

/// 记录用户服药历史的模型类
class MedicationRecord {
  final String id;
  final String reminderId; // 关联的提醒ID
  final String medicineName; // 药品名称
  final String dosage; // 剂量
  final String unit; // 单位
  final DateTime takenAt; // 服药时间
  final bool takenOnTime; // 是否按时服药
  final String notes; // 备注

  MedicationRecord({
    required this.id,
    required this.reminderId,
    required this.medicineName,
    required this.dosage,
    required this.unit,
    required this.takenAt,
    this.takenOnTime = true,
    this.notes = '',
  });

  /// 从JSON创建MedicationRecord对象
  factory MedicationRecord.fromJson(Map<String, dynamic> json) {
    return MedicationRecord(
      id: json['id'],
      reminderId: json['reminderId'],
      medicineName: json['medicineName'],
      dosage: json['dosage'],
      unit: json['unit'],
      takenAt: DateTime.parse(json['takenAt']),
      takenOnTime: json['takenOnTime'] ?? true,
      notes: json['notes'] ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reminderId': reminderId,
      'medicineName': medicineName,
      'dosage': dosage,
      'unit': unit,
      'takenAt': takenAt.toIso8601String(),
      'takenOnTime': takenOnTime,
      'notes': notes,
    };
  }
}