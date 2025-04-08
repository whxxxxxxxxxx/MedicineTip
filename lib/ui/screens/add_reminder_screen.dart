import 'package:flutter/material.dart';
import '../../services/reminder_service.dart';
import '../../services/ai_service.dart';

class AddReminderScreen extends StatefulWidget {
  final ReminderService reminderService;
  final AIService aiService;

  const AddReminderScreen({
    Key? key,
    required this.reminderService,
    required this.aiService,
  }) : super(key: key);

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();
  
  final List<TimeOfDay> _scheduledTimes = [TimeOfDay(hour: 8, minute: 0)];
  bool _isProcessing = false;
  bool _isVoiceInputMode = false;
  String _voiceInputStatus = '点击麦克风开始录音';

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processTextInput(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 调用AI服务解析文本
      final result = await widget.aiService.parseTextInput(text);
      
      // 填充表单
      _medicineNameController.text = result['medicineName'] ?? '';
      _dosageController.text = result['dosage'] ?? '';
      _unitController.text = result['unit'] ?? '';
      _notesController.text = text;
      
      // 处理时间
      if (result['scheduledTimes'] != null && result['scheduledTimes'] is List) {
        final times = result['scheduledTimes'] as List<DateTime>;
        setState(() {
          _scheduledTimes.clear();
          for (final time in times) {
            _scheduledTimes.add(TimeOfDay(hour: time.hour, minute: time.minute));
          }
          if (_scheduledTimes.isEmpty) {
            _scheduledTimes.add(const TimeOfDay(hour: 8, minute: 0));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _startVoiceRecording() async {
    // TODO: 实现语音录制功能
    setState(() {
      _voiceInputStatus = '正在录音...';
    });
    
    // 模拟录音过程
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _voiceInputStatus = '正在处理语音...';
    });
    
    // 模拟语音处理
    await Future.delayed(const Duration(seconds: 1));
    
    // 模拟解析结果
    await _processTextInput('每天早上8点吃阿司匹林一片');
    
    setState(() {
      _voiceInputStatus = '点击麦克风开始录音';
      _isVoiceInputMode = false;
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 将TimeOfDay转换为DateTime
      final now = DateTime.now();
      final scheduledTimes = _scheduledTimes.map((time) {
        return DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
      }).toList();

      // 添加提醒
      await widget.reminderService.addReminder(
        medicineName: _medicineNameController.text,
        dosage: _dosageController.text,
        unit: _unitController.text,
        scheduledTimes: scheduledTimes,
        notes: _notesController.text,
      );

      // 返回上一页
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加用药提醒'),
        actions: [
          IconButton(
            icon: Icon(_isVoiceInputMode ? Icons.text_fields : Icons.mic),
            onPressed: () {
              setState(() {
                _isVoiceInputMode = !_isVoiceInputMode;
              });
            },
          ),
        ],
      ),
      body: _isVoiceInputMode ? _buildVoiceInputUI() : _buildFormUI(),
    );
  }

  Widget _buildVoiceInputUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _voiceInputStatus,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _startVoiceRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '请说出您的用药提醒信息，例如：\n"每天早上8点吃阿司匹林一片"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 文本输入模式
            TextFormField(
              decoration: const InputDecoration(
                labelText: '直接输入描述（可选）',
                hintText: '例如：每天早上8点吃阿司匹林一片',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onFieldSubmitted: _processTextInput,
            ),
            const SizedBox(height: 16),
            
            // 药品名称
            TextFormField(
              controller: _medicineNameController,
              decoration: const InputDecoration(
                labelText: '药品名称 *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入药品名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 剂量和单位（放在同一行）
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(
                      labelText: '剂量 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入剂量';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: '单位 *',
                      hintText: '片/毫升/粒',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入单位';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 服药时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('服药时间 *', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                ..._buildTimeSelectors(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _scheduledTimes.add(const TimeOfDay(hour: 12, minute: 0));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加时间'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 备注
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // 保存按钮
            ElevatedButton(
              onPressed: _isProcessing ? null : _saveReminder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('保存提醒', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimeSelectors() {
    return List.generate(_scheduledTimes.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _scheduledTimes[index],
                  );
                  if (time != null) {
                    setState(() {
                      _scheduledTimes[index] = time;
                    });
                  }
                },
                child: Text(
                  '${_scheduledTimes[index].hour.toString().padLeft(2, '0')}:${_scheduledTimes[index].minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (_scheduledTimes.length > 1)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _scheduledTimes.removeAt(index);
                  });
                },
              ),
          ],
        ),
      );
    });
  }
}