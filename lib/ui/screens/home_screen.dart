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

  bool _hasNotificationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    _loadReminders();
  }

  Future<void> _checkNotificationPermission() async {
    final hasPermission = await widget.reminderService.notificationService.checkPermissionStatus();
    setState(() {
      _hasNotificationPermission = hasPermission;
    });

    if (!hasPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要通知权限'),
            content: const Text('为了确保您能及时收到用药提醒，请在系统设置中开启通知权限。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('稍后再说'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final granted = await widget.reminderService.notificationService.requestPermission();
                  setState(() {
                    _hasNotificationPermission = granted;
                  });
                },
                child: const Text('去开启'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 确保数据已加载
      await widget.reminderService.loadData();
      // 获取提醒列表
      final reminders = widget.reminderService.reminders;
      print('已加载提醒列表，共 ${reminders.length} 条记录');
      for (var reminder in reminders) {
        print('提醒ID: ${reminder.id}, 药品名: ${reminder.medicineName}, 是否启用: ${reminder.isActive}');
      }
      
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
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
          print('点击提醒项：ID=${reminder.id}, 药品名=${reminder.medicineName}');
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