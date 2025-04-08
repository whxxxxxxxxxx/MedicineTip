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

    // 获取所有服药记录
    final records = widget.reminderService.medicationRecords;
    
    // 按时间排序（最新的在前面）
    records.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    
    setState(() {
      _records = records;
      _isLoading = false;
    });
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
      leading: CircleAvatar(
        backgroundColor: record.takenOnTime ? Colors.green : Colors.orange,
        child: Icon(
          record.takenOnTime ? Icons.check : Icons.access_time,
          color: Colors.white,
        ),
      ),
      title: Text(record.medicineName),
      subtitle: Text(
        '${record.dosage} ${record.unit} · ${_timeFormat.format(record.takenAt)}',
      ),
      trailing: record.notes.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('备注'),
                    content: Text(record.notes),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
    );
  }
}