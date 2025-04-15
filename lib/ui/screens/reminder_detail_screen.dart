import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../../services/reminder_service.dart';

class ReminderDetailScreen extends StatefulWidget {
  final String reminderId;
  final ReminderService reminderService;

  const ReminderDetailScreen({
    super.key,
    required this.reminderId,
    required this.reminderService,
  }) ;

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  Reminder? _reminder;
  List<MedicationRecord> _records = [];
  bool _isLoading = true;
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取提醒详情
      print('正在加载提醒详情，ID: ${widget.reminderId}');
      final reminder = widget.reminderService.getReminderById(widget.reminderId);
      
      if (reminder == null) {
        print('提醒不存在，ID: ${widget.reminderId}');
        // 提醒不存在，返回上一页
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('提醒不存在')),
          );
          Navigator.pop(context);
        }
        return;
      }
      print('提醒详情加载成功：${reminder.toString()}');
      
      // 获取该提醒的服药记录
      final records = widget.reminderService.getMedicationRecordsForReminder(widget.reminderId);
      print('已加载服药记录，共 ${records.length} 条');
      
      // 按时间排序（最新的在前面）
      records.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      
      setState(() {
        _reminder = reminder;
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _recordMedication() async {
    if (_reminder == null) return;
    
    try {
      await widget.reminderService.recordMedication(
        reminderId: widget.reminderId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已记录服药')),
        );
      }
      
      _loadData(); // 重新加载数据
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('记录失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个提醒吗？所有相关的服药记录也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed != true){
      return;
    }
    
    try {
      print('正在删除提醒，ID: ${widget.reminderId}');
      await widget.reminderService.deleteReminder(widget.reminderId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提醒已删除')),
        );
        Navigator.pop(context, true); // 返回上一页并刷新
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteReminder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _isLoading || _reminder == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _recordMedication,
              icon: const Icon(Icons.check),
              label: const Text('记录服药'),
            ),
    );
  }

  Widget _buildBody() {
    if (_reminder == null) {
      return const Center(child: Text('提醒不存在'));
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提醒信息卡片
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _reminder!.medicineName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Switch(
                        value: _reminder!.isActive,
                        onChanged: (value) async {
                          final updatedReminder = _reminder!.copyWith(isActive: value);
                          await widget.reminderService.updateReminder(updatedReminder);
                          _loadData(); // 重新加载数据
                          Navigator.pop(context, true); // 返回上一页并刷新
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '剂量: ${_reminder!.dosage} ${_reminder!.unit}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text('服药时间:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _reminder!.scheduledTimes.map((time) {
                      return Chip(
                        label: Text(_timeFormat.format(time)),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // 服药记录
          const SizedBox(height: 24),
          Text(
            '服药记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _records.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('暂无服药记录'),
                    ),
                  ),
                )
              : Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(_dateTimeFormat.format(record.takenAt)),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}