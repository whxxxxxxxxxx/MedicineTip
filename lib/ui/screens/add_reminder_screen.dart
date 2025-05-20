import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/reminder_service.dart';
import '../../services/ai_service.dart';

class AddReminderScreen extends StatefulWidget {
  final ReminderService reminderService;
  final AIService aiService;

  const AddReminderScreen({
    super.key,
    required this.reminderService,
    required this.aiService,
  });

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _unitController = TextEditingController();
  final _textInputController = TextEditingController();
  
  final List<TimeOfDay> _scheduledTimes = [TimeOfDay(hour: 8, minute: 0)];
  bool _isProcessing = false;
  bool _isVoiceInputMode = false;
  bool _isRecording = false;
  String _voiceInputStatus = '按住说话';
  String _recognizedText = ''; // 添加识别文本状态

  @override
  void initState() {
    super.initState();
    // 设置语音识别回调
    widget.aiService.onSpeechRecognized = _updateRecognizedText;
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _textInputController.dispose();
    // 清除回调
    widget.aiService.onSpeechRecognized = null;
    super.dispose();
  }

  // 更新识别文本的回调函数
  void _updateRecognizedText(String text) {
    if (mounted) {
      setState(() {
        // 保留中间结果的标点符号处理
        _recognizedText = text.replaceAll(' ，', '，') // 处理标点空格
                            .replaceAll(' 。', '。')
                            .replaceAll(' 、', '、');
      });
    }
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
      
      // 处理时间
      if (result['scheduledTimes'] != null && result['scheduledTimes'] is List) {
        final times = result['scheduledTimes'] as List;
        setState(() {
          _scheduledTimes.clear();
          for (final timeStr in times) {
            try {
              final dt = DateTime.parse(timeStr);
              _scheduledTimes.add(TimeOfDay(hour: dt.hour, minute: dt.minute));
            } catch (_) {
              // 解析失败时跳过
            }
          }
          if (_scheduledTimes.isEmpty) {
            _scheduledTimes.add(const TimeOfDay(hour: 8, minute: 0));
          }
        });
      }
      
      // 切换到表单界面
      setState(() {
        _isVoiceInputMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _startVoiceRecording() async {
    // 先检查麦克风权限
    final hasPermission = await widget.aiService.checkMicrophonePermission();
    if (!hasPermission) {
      // 请求麦克风权限
      final permissionGranted = await widget.aiService.requestMicrophonePermission();
      if (!permissionGranted) {
        if (mounted) {
          // 显示权限设置对话框
          _showPermissionDialog();
          return;
        }
      }
    }
    
    setState(() {
      _isRecording = true;
      _voiceInputStatus = '正在录音...';
      _recognizedText = ''; // 清空之前的识别文本
    });
    
    try {
      // 调用AI服务开始录音
      await widget.aiService.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }    
  }
  
  // 显示权限设置对话框
  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('需要麦克风权限'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('为了使用语音输入功能，我们需要访问您的麦克风。'),
                Text('请在设置中允许麦克风权限。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('去设置'),
              onPressed: () {
                Navigator.of(context).pop();
                _openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
  
  // 打开应用设置页面
  Future<void> _openAppSettings() async {
    try {
      final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
      await channel.invokeMethod('openAppSettings');
    } catch (e) {
      print('打开应用设置失败: $e');
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;
    
    setState(() {
      _isRecording = false;
      _voiceInputStatus = '正在处理语音...';
    });
    
    try {
      // 停止录音
      await widget.aiService.stopRecording();
      
      // 获取识别结果
      final recognizedText = widget.aiService.getRecognizedText();
      if (recognizedText.isNotEmpty) {
        // 将识别结果填入文本输入框
        _textInputController.text = recognizedText;
        // 处理识别结果
        await _processTextInput(recognizedText);
      } else {
        setState(() {
          _voiceInputStatus = '未能识别语音，请重试';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _voiceInputStatus = '按住说话';
        });
      }
    }
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
      );

      // 隐藏键盘
      FocusScope.of(context).unfocus();
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        
        // 短暂延迟后返回上一页
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        });
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
              
              // 如果切换到语音输入模式，则初始化WebSocket
              if (_isVoiceInputMode) {
                widget.aiService.initWebSocket().catchError((e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('初始化语音服务失败: $e')),
                    );
                  }
                });
              }
            },
          ),
        ],
      ),
      body: _isVoiceInputMode ? _buildVoiceInputUI() : _buildFormUI(),
    );
  }

  Widget _buildVoiceInputUI() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 文本输入模式
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: '直接输入描述（可选）',
                hintText: '例如：每天早上8点吃阿司匹林一片',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onFieldSubmitted: _processTextInput,
              controller: _textInputController,
            ),
          ),
          
          // 识别文本显示区域 - 始终显示，即使为空
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '实时识别结果:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _recognizedText.isEmpty
                        ? Text(
                            _isRecording ? '正在聆听...' : '等待语音输入...',
                            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          )
                        : Text(
                            _recognizedText,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            _voiceInputStatus,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTapDown: (_) => _startVoiceRecording(),
            onTapUp: (_) => _stopVoiceRecording(),
            onTapCancel: () => _stopVoiceRecording(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording 
                  ? Theme.of(context).primaryColor.withOpacity(0.7)
                  : Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 5,
                      )
                    ]
                  : null,
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '请说出您的用药提醒信息，例如：\n"每天早上8点吃阿司匹林一片"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('智能解析并填写'),
            onPressed: _isProcessing
                ? null
                : () {
                    final text = _textInputController.text.trim();
                    if (text.isNotEmpty) {
                      _processTextInput(text);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入描述后再解析')),
                      );
                    }
                  },
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