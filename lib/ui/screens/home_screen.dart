import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import '../../services/reminder_service.dart';
// 需要创建 reminder_list_item.dart 文件
import '../widgets/reminder_list_item.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  final ReminderService reminderService;

  const HomeScreen({Key? key, required this.reminderService}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    // 获取提醒列表
    final reminders = widget.reminderService.reminders;
    
    setState(() {
      _reminders = reminders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用药提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 导航到添加提醒页面
          final result = await Navigator.pushNamed(context, '/add-reminder');
          if (result == true) {
            _loadReminders();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reminders.isEmpty) {
      return const EmptyState(
        icon: Icons.medication,
        title: '没有用药提醒',
        message: '点击下方的加号按钮添加新的用药提醒',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView.builder(
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          // 需要先创建并导入 ReminderListItem widget
          return ReminderListItem(
            reminder: reminder,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/reminder-detail',
                arguments: reminder.id,
              ).then((value) {
                if (value == true) {
                  _loadReminders();
                }
              });
            },
            onToggleActive: (isActive) async {
              final updatedReminder = reminder.copyWith(isActive: isActive);
              await widget.reminderService.updateReminder(updatedReminder);
              _loadReminders();
            },
          );
        },
      ),
    );
  }
}