import 'package:flutter/material.dart';
import '../../services/reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  final ReminderService reminderService;

  const SettingsScreen({
    Key? key,
    required this.reminderService,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 加载设置
      // TODO: 实现从存储服务加载设置
    } catch (e) {
      // 处理错误
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 保存设置
      // TODO: 实现保存设置到存储服务
    } catch (e) {
      // 处理错误
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 通知设置
                ListTile(
                  title: const Text('启用通知'),
                  subtitle: const Text('接收用药提醒通知'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                ),
                const Divider(),
                
                // 关于应用
                const ListTile(
                  title: Text('关于'),
                  subtitle: Text('用药提醒 v1.0.0'),
                ),
                
                // 清除数据（仅用于测试）
                ListTile(
                  title: const Text('清除所有数据'),
                  subtitle: const Text('删除所有提醒和记录（仅用于测试）'),
                  trailing: const Icon(Icons.delete_forever),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('此操作将删除所有提醒和记录，且无法恢复。确定要继续吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              // TODO: 实现清除所有数据
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}