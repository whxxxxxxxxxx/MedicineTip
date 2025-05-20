import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// AI服务类，用于解析用户输入的药物信息
class AIService {
  final String? apiKey;
  WebSocketChannel? _channel;
  StreamController<Uint8List>? _audioStreamController;
  bool _isRecording = false;
  StreamSubscription? _wsSubscription;
  Timer? _heartbeatTimer;
  String uuid = '';
  FlutterSoundRecorder recorderModule = FlutterSoundRecorder();
  
  // 添加语音识别结果回调
  ValueChanged<String>? onSpeechRecognized;
  String _recognizedText = '';
  StreamSubscription? _audioStreamSubscription;  // 添加音频流订阅的引用

  AIService() : apiKey = dotenv.env['API_KEY'];

  /// 解析用户输入的文本，提取药物信息
  /// 
  /// 参数:
  /// - [input]: 用户输入的文本
  /// 
  /// 返回: 解析后的药物信息Map
  Future<Map<String, dynamic>> parseTextInput(String input) async {
    // 优化后的提示词，要求AI严格输出指定JSON格式
    final apiKey = dotenv.env['API_KEY'];
    final url = Uri.parse('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      "model": "qwen-plus",
      "messages": [
        {
          "role": "system",
          "content":
              "你是一个药物信息解析助手，请从用户输入中提取药品名、剂量、单位、服药时间和备注，并严格以如下JSON格式返回：{\"medicineName\":\"药品名\",\"dosage\":\"剂量\",\"unit\":\"单位\",\"scheduledTimes\":[\"2024-06-01T08:00:00\"],\"notes\":\"备注\"}。scheduledTimes必须为字符串数组，时间为ISO8601格式，所有字段都必须有。不要输出多余内容。"
        },
        {
          "role": "user",
          "content": "用户输入：$input"
        }
      ]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        // final data = jsonDecode(response.body);
        final bodyString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(bodyString);
        print(data);  
        final aiContentRaw = data['choices']?[0]?['message']?['content'] ?? '';
        // 去除 markdown 代码块包裹
        final aiContent = aiContentRaw.replaceAll(RegExp(r'```json|```'), '').trim();
        Map<String, dynamic> result;
        try {
          result = jsonDecode(aiContent);
          // 字段类型校验与转换
          if (result['scheduledTimes'] is List) {
            result['scheduledTimes'] = (result['scheduledTimes'] as List)
                .map((e) => e is String ? e : (e is DateTime ? e.toIso8601String() : e.toString()))
                .toList();
          } else {
            result['scheduledTimes'] = [];
          }
        } catch (_) {
          // 本地兜底解析，所有字段都保证有，scheduledTimes为字符串数组
          final times = _extractScheduledTimes(aiContent.isNotEmpty ? aiContent : input);
          result = {
            'medicineName': _extractMedicineName(aiContent.isNotEmpty ? aiContent : input),
            'dosage': _extractDosage(aiContent.isNotEmpty ? aiContent : input),
            'unit': _extractUnit(aiContent.isNotEmpty ? aiContent : input),
            'scheduledTimes': times.map((dt) => dt.toIso8601String()).toList(),
            'notes': '',
          };
        }
        // 保证所有字段都存在
        result['medicineName'] ??= '';
        result['dosage'] ??= '';
        result['unit'] ??= '';
        result['scheduledTimes'] ??= [];
        result['notes'] ??= '';
        print(result);
        return result;
      } else {
        throw Exception('AI服务请求失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('AI服务调用异常: $e');
      // 本地兜底解析，所有字段都保证有，scheduledTimes为字符串数组
      final times = _extractScheduledTimes(input);
      final result = {
        'medicineName': _extractMedicineName(input),
        'dosage': _extractDosage(input),
        'unit': _extractUnit(input),
        'scheduledTimes': times.map((dt) => dt.toIso8601String()).toList(),
        'notes': input,
      };
      return result;
    }
  }
  
  /// 初始化WebSocket连接
  Future<void> initWebSocket() async {
    if (_channel != null) {
      print('WebSocket已经初始化，跳过连接');
      return; // 如果已经初始化，则直接返回
    }
    
    print('开始初始化WebSocket连接...');
    // 确保API key存在
    if (apiKey == null || apiKey!.isEmpty) {
      print('WebSocket连接失败: API key为空');
      throw Exception('API key为空，无法建立WebSocket连接');
    }
    
    // 打印部分API key用于调试（只显示前4位和后4位）
    final maskedKey = apiKey!.length > 8 
        ? '${apiKey!.substring(0, 4)}...${apiKey!.substring(apiKey!.length - 4)}'
        : '***';
    print('使用API key: $maskedKey');
    
    try {
      // 使用dart:io的WebSocket类，可以直接传递headers
      final socket = await WebSocket.connect(
        'wss://dashscope.aliyuncs.com/api-ws/v1/inference',
        headers: {
          'Authorization': 'Bearer $apiKey',
          'user-agent': 'MedicineTip/1.0',
          'X-DashScope-DataInspection': 'enable',
        },
      );
      
      // 使用IOWebSocketChannel包装socket
      _channel = IOWebSocketChannel(socket);
      
      print('WebSocket连接已建立，认证信息已通过HTTP头传递');
      
      // 启动心跳定时器，每30秒发送一次心跳包
      _startHeartbeat();
      
      _setupWebSocketListeners();
      _sendStartMessage();
    } catch (e) {
      print('WebSocket连接失败: $e');
      _channel = null;
      rethrow;
    }
  }
    /// 发送开始语音识别任务的消息
  void _sendStartMessage() {
    if (_channel == null) {
      print('WebSocket未连接，无法发送开始消息');
      return;
    }
    
    try {
      // 生成随机UUID作为任务ID
      uuid = _generateUuid();
      // 构建run-task消息
      final message = {
        'header': {
          'action': 'run-task',
          'task_id': uuid,
          'streaming': 'duplex'
        },
        'payload': {
          'task_group': 'audio',
          'task': 'asr',
          'function': 'recognition',
          'model': 'paraformer-realtime-v2',
          'parameters': {
            'format': 'pcm',
            'sample_rate': 16000,
            'disfluency_removal_enabled': false,
            'enable_punctuation': true,  // 启用标点符号预测
            'enable_inverse_text_normalization': true,  // 启用逆文本正则化
            'language_hints': ['zh'],  // 使用中文作为默认语言
            'hot_words': [],  // 可以添加热词提高识别准确率
            'hot_words_weight': 0.8  // 热词权重
          },
          'input': {}
        }
      };
      
      // 发送消息
      print('发送语音识别任务开始消息: $uuid');
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      print('发送开始消息失败: $e');
    }
  }
  
  /// 生成随机UUID
  String _generateUuid() {
    final _uuid = Uuid();
    return _uuid.v4();
  }


  /// 启动心跳定时器
  void _startHeartbeat() {
    // 取消已有的心跳定时器
    _heartbeatTimer?.cancel(); // 需要增加定时器判空逻辑
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // 建议增加连接状态检查
      if (_channel != null && _channel!.closeCode == null) {
        try {
          print('发送WebSocket心跳包...');
          // 构建心跳消息
          _channel?.sink.add(jsonEncode({
            'header': {
              'action': 'ping'
            },
            'payload': {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              "input": {}
            }
          }));
        } catch (e) {
          print('发送心跳包失败: $e');
          _heartbeatTimer?.cancel();
        }
      } else {
        // 如果通道已关闭，取消定时器
        timer.cancel();
        _heartbeatTimer = null;
      }
    });
  }

  /// 设置WebSocket消息监听器
  void _setupWebSocketListeners() {
    _wsSubscription?.cancel();
    _wsSubscription = _channel?.stream.listen(
          (message) {
        try {
          // 直接调用处理方法（在主线程执行）
          final result = _processWebSocketMessage(message);

          if (result != null && result.isNotEmpty) {
            if (result == '__END__') {
              print('语音识别结束');
            } else {
              _recognizedText = result;
              onSpeechRecognized?.call(_recognizedText); // 直接更新 UI 相关变量（主线程安全）
            }
          }
        } catch (error) {
          print('处理WebSocket消息失败: $error');
          stopRecording(); // 错误处理
        }
      },
      onError: (error) {
        print('WebSocket连接错误: $error');
        stopRecording();
      },
      onDone: () {
        print('WebSocket连接关闭');
        stopRecording();
      },
    );
  }
  
  /// 在后台线程中处理WebSocket消息
  String? _processWebSocketMessage(dynamic message) {
    try {
      print('Received: $message');
      final Map<String, dynamic> data = jsonDecode(message);
      
      // 处理语音识别结果
      if (data['type'] == 'transcript') {
        final String text = data['text'] ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      } else if (data['type'] == 'end') {
        // 语音识别结束，返回特殊标记
        return '__END__';
      }
      
      // 处理任务状态消息
      if (data['header'] != null && data['payload'] != null) {
        final header = data['header'];
        final event = header['event'];
        final taskId = header['task_id'];
        
        if (event == 'task-started') {
          print('语音识别任务已开始，任务ID: $taskId');
        } else if (event == 'task-completed' || event == 'task-finished') {
          print('语音识别任务已完成，任务ID: $taskId');
          return '__END__';
        } else if (event == 'task-failed') {
          print('语音识别任务失败，任务ID: $taskId，原因: ${data['payload']['error'] ?? "未知错误"}');
        } else if (event == 'result-generated') {
          // 处理实时语音识别结果
          final payload = data['payload'];
          if (payload != null && payload['output']?['sentence'] != null) {
            final sentence = payload['output']['sentence'];
            final String text = sentence['text'] ?? '';
            final bool isFinal = sentence['end_time'] != null;

            if (text.isNotEmpty) {
              print('${isFinal ? '最终' : '中间'}识别结果: $text');
              // 实时更新识别文本（包括中间结果）
              if (onSpeechRecognized != null) {
                onSpeechRecognized!(text);
              }
              // 仅当最终结果时返回完整文本
              return isFinal ? text : null; 
            }
          }
        } else if (event == 'ping-response' || event == 'pong') {
          // 心跳响应
          print('收到心跳响应');
        } else {
          // 处理其他未知事件
          print('收到未知事件: $event, 任务ID: $taskId');
        }
      }
      
      // 处理心跳响应
      if (data['type'] == 'pong') {
        print('收到心跳响应: ${data['timestamp']}');
      }
    } catch (e) {
      print('解析WebSocket消息失败: $e');
    }
    return null;
  }

  /// 获取当前识别的文本
  String getRecognizedText() {
    return _recognizedText;
  }

  void setupAudioStreamListener() {
    // 先取消之前的订阅
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    if (_audioStreamController != null) {
      _audioStreamSubscription = _audioStreamController!.stream.listen(
        (Uint8List data) {
          sendAudioDataViaWebSocket(data);
        },
        onError: (error) {
          print('音频流发生错误: $error');
          stopRecording();
        },
        cancelOnError: true,
      );
    }
  }

  Future<void> sendAudioDataViaWebSocket(Uint8List data) async {
    if (_isRecording && _channel != null) {
      try {
        _channel!.sink.add(data);
        print('发送了 ${data.length} 字节的音频数据');
      } catch (e) {
        print('发送音频数据时出错: $e');
        await stopRecording();
        rethrow;
      }
    }
  }

  /// 开始语音录制
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      // 重置识别文本
      _recognizedText = '';
      onSpeechRecognized?.call('');
      
      // 确保WebSocket已初始化
      await initWebSocket();

      // 先创建音频流控制器
      _audioStreamController = StreamController<Uint8List>();
      setupAudioStreamListener();

      //开启录音
      await recorderModule.openRecorder();
      //设置订阅计时器
      await recorderModule.setSubscriptionDuration(const Duration(milliseconds: 10));
      _isRecording = true;

      await recorderModule.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
        audioSource: AudioSource.microphone,
      );

    } catch (e) {
      print('Error starting recording: $e');
      await stopRecording();
      rethrow;
    }
  }


  
  /// 检查麦克风权限
  Future<bool> checkMicrophonePermission() async {
    try {
      final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
      final bool? result = await channel.invokeMethod('checkMicrophonePermission');
      return result ?? false;
    } catch (e) {
      print('检查麦克风权限失败: $e');
      return false;
    }
  }
  
  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    try {
      final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
      final bool? result = await channel.invokeMethod('requestMicrophonePermission');
      return result ?? false;
    } catch (e) {
      print('请求麦克风权限失败: $e');
      return false;
    }
  }

  /// 释放所有资源
  Future<void> dispose() async {
    await stopRecording();
    await _cleanupResources();
  }

  /// 清理所有资源
  Future<void> _cleanupResources() async {
    // 取消音频流订阅
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    // 取消心跳定时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // 取消WebSocket订阅
    await _wsSubscription?.cancel();
    _wsSubscription = null;

    // 关闭WebSocket连接
    if (_channel != null) {
      try {
        await _channel!.sink.close(ws_status.normalClosure);
      } catch (e) {
        print('关闭WebSocket连接时出错: $e');
      }
      _channel = null;
    }

    // 关闭音频流控制器
    if (_audioStreamController != null) {
      try {
        await _audioStreamController!.close();
      } catch (e) {
        print('关闭音频流控制器时出错: $e');
      }
      _audioStreamController = null;
    }

    // 关闭录音器
    try {
      await recorderModule.closeRecorder();
    } catch (e) {
      print('关闭录音器时出错: $e');
    }
  }

  /// 停止语音录制
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      _isRecording = false;

      // 发送结束任务消息
      if (_channel != null) {
        try {
          // 发送finish-task消息通知服务端结束任务
          _channel?.sink.add(jsonEncode({
            'header': {
              'action': 'finish-task',
              'task_id': uuid,
              'streaming': 'duplex'
            },
            'payload':{
              "input": {}
            }
          }));
          
          // 等待一小段时间，确保服务端处理完成
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print('发送结束任务消息失败: $e');
        }
      }

      // 清理资源
      await _cleanupResources();

    } catch (e) {
      print('Error stopping recording: $e');
      rethrow;
    }
  }

  /// 添加音频数据到流
  Future<void> addAudioData(Uint8List data) async {
    if (_isRecording && _audioStreamController != null && _channel != null) {
      try {
        // 直接发送二进制音频数据
        _channel?.sink.add(data);
      } catch (e) {
        print('Error sending audio data: $e');
        await stopRecording();
        rethrow;
      }
    }
  }
  // 以下是辅助方法，用于从文本中提取信息
  String _extractMedicineName(String input) {
    // 简单的实现，实际应该使用更复杂的算法
    final words = input.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (words[i].contains('吃') && i + 1 < words.length) {
        return words[i + 1];
      }
    }
    return '';
  }

  String _extractDosage(String input) {
    // 简单的实现
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(input);
    return match?.group(0) ?? '1';
  }

  String _extractUnit(String input) {
    // 简单的实现
    final units = ['片', '粒', '毫克', '克', 'mg', 'g'];
    for (final unit in units) {
      if (input.contains(unit)) {
        return unit;
      }
    }
    return '片';
  }

  List<DateTime> _extractScheduledTimes(String input) {
    // 简单的实现
    final now = DateTime.now();
    if (input.contains('早上') || input.contains('早晨')) {
      return [DateTime(now.year, now.month, now.day, 8, 0)];
    } else if (input.contains('中午')) {
      return [DateTime(now.year, now.month, now.day, 12, 0)];
    } else if (input.contains('晚上')) {
      return [DateTime(now.year, now.month, now.day, 19, 0)];
    }
    return [DateTime(now.year, now.month, now.day, 8, 0)];
  }
}


