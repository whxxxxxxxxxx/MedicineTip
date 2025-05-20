import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// 麦克风服务类，用于管理应用的麦克风权限
class MicrophoneService {
  bool _isInitialized = false;
  bool _hasPermission = false;

  /// 获取麦克风权限状态
  Future<bool> checkPermissionStatus() async {
    if (Platform.isAndroid) {
      // 使用MethodChannel检查Android权限状态
      try {
        final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
        final bool? status = await channel.invokeMethod('checkMicrophonePermission');
        if (status != null) {
          _hasPermission = status;
          return _hasPermission;
        }
        return false;
      } catch (e) {
        print('检查麦克风权限失败: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS权限状态检查
      try {
        final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
        final bool? status = await channel.invokeMethod('checkMicrophonePermission');
        if (status != null) {
          _hasPermission = status;
          return _hasPermission;
        }
        return false;
      } catch (e) {
        print('检查麦克风权限失败: $e');
        return false;
      }
    }
    
    // 默认返回true，因为其他平台可能不需要显式权限
    return true;
  }

  /// 初始化麦克风服务
  Future<void> init() async {
    if (_isInitialized) return;
    
    await checkPermissionStatus();
    _isInitialized = true;
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    // 处理iOS权限申请
    if (Platform.isIOS) {
      try {
        final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
        final bool? result = await channel.invokeMethod('requestMicrophonePermission');
        if (result != null) {
          _hasPermission = result;
          return result;
        }
        return false;
      } catch (e) {
        print('请求麦克风权限失败: $e');
        return false;
      }
    }
    
    // 处理Android权限申请
    if (Platform.isAndroid) {
      try {
        final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
        final bool? result = await channel.invokeMethod('requestMicrophonePermission');
        if (result != null) {
          _hasPermission = result;
          return result;
        }
        return false;
      } catch (e) {
        print('请求麦克风权限失败: $e');
        return false;
      }
    }
    
    // 如果不是iOS或Android，默认返回true
    return true;
  }

  /// 显示权限设置对话框
  Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog<void>(
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

  /// 打开应用设置页面
  Future<void> _openAppSettings() async {
    try {
      final MethodChannel channel = MethodChannel('com.medicinetip.app/microphone');
      await channel.invokeMethod('openAppSettings');
    } catch (e) {
      print('打开应用设置失败: $e');
    }
  }
}