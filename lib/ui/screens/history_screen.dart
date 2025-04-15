import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';
import '../../services/reminder_service.dart';
import '../widgets/empty_state.dart';

class HistoryScreen extends StatefulWidget {
  final ReminderService reminderService;

  const HistoryScreen({Key? key, required this.reminderService}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MedicationRecord> _records = [];
  bool _isLoading = true;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 确保数据已加载
      await widget.reminderService.loadData();
      
      // 获取所有服药记录并创建新的可修改列表
      final records = List<MedicationRecord>.from(widget.reminderService.medicationRecords);
      print('已加载服药记录，共 ${records.length} 条记录');
      
      // 按时间排序（最新的在前面）
      records.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      print('加载服药记录失败: $e');
      setState(() {
        _records = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服药历史'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: '没有服药记录',
        message: '您的服药记录将显示在这里',
      );
    }

    // 按日期分组记录
    final Map<String, List<MedicationRecord>> recordsByDate = {};
    for (final record in _records) {
      final dateString = _dateFormat.format(record.takenAt);
      if (!recordsByDate.containsKey(dateString)) {
        recordsByDate[dateString] = [];
      }
      recordsByDate[dateString]!.add(record);
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        itemCount: recordsByDate.length,
        itemBuilder: (context, index) {
          final date = recordsByDate.keys.elementAt(index);
          final dayRecords = recordsByDate[date]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  date,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...dayRecords.map((record) => _buildRecordItem(record)).toList(),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordItem(MedicationRecord record) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
      title: Text(record.medicineName),
      subtitle: Text(
        '${record.dosage} ${record.unit} · ${_timeFormat.format(record.takenAt)}',
      ),
    );
  }
}