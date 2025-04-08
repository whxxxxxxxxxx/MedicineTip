
/// AI服务类，用于解析用户输入的药物信息
class AIService {
  /// 解析用户输入的文本，提取药物信息
  /// 
  /// 参数:
  /// - [input]: 用户输入的文本
  /// 
  /// 返回: 解析后的药物信息Map
  Future<Map<String, dynamic>> parseTextInput(String input) async {
    // TODO: 实现与AI服务的实际集成
    // 这里是模拟的解析结果
    await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
    
    // 简单的解析逻辑，实际应用中应该调用AI API
    final result = {
      'medicineName': _extractMedicineName(input),
      'dosage': _extractDosage(input),
      'unit': _extractUnit(input),
      'scheduledTimes': _extractScheduledTimes(input),
      'notes': input,
    };
    
    return result;
  }
  
  /// 解析用户的语音输入
  /// 
  /// 参数:
  /// - [audioBytes]: 语音数据的字节数组
  /// 
  /// 返回: 解析后的药物信息Map
  Future<Map<String, dynamic>> parseVoiceInput(List<int> audioBytes) async {
    // TODO: 实现语音转文本，然后调用文本解析
    // 这里是模拟的解析结果
    await Future.delayed(const Duration(seconds: 2)); // 模拟网络请求
    
    // 模拟语音转文本
    const text = "每天早上8点吃阿司匹林一片";
    
    // 调用文本解析
    return parseTextInput(text);
  }
  
  // 以下是简单的文本解析辅助方法，实际应用中应该使用更复杂的NLP或AI模型
  
  String _extractMedicineName(String input) {
    // 简单示例：提取可能的药物名称
    final medicines = ['阿司匹林', '布洛芬', '感冒药', '维生素C', '降压药'];
    for (final medicine in medicines) {
      if (input.contains(medicine)) {
        return medicine;
      }
    }
    return '未知药物';
  }
  
  String _extractDosage(String input) {
    // 简单示例：提取剂量
    final RegExp dosageRegex = RegExp(r'(\d+)(片|毫克|克|毫升|粒)');
    final match = dosageRegex.firstMatch(input);
    if (match != null) {
      return match.group(1) ?? '1';
    }
    return '1'; // 默认剂量
  }
  
  String _extractUnit(String input) {
    // 简单示例：提取单位
    final RegExp unitRegex = RegExp(r'\d+(片|毫克|克|毫升|粒)');
    final match = unitRegex.firstMatch(input);
    if (match != null) {
      return match.group(1) ?? '片';
    }
    return '片'; // 默认单位
  }
  
  List<DateTime> _extractScheduledTimes(String input) {
    // 简单示例：提取时间
    final List<DateTime> times = [];
    final now = DateTime.now();
    
    // 检查是否包含早上/中午/晚上的关键词
    if (input.contains('早上') || input.contains('早晨')) {
      times.add(DateTime(now.year, now.month, now.day, 8, 0));
    }
    if (input.contains('中午')) {
      times.add(DateTime(now.year, now.month, now.day, 12, 0));
    }
    if (input.contains('晚上') || input.contains('傍晚')) {
      times.add(DateTime(now.year, now.month, now.day, 19, 0));
    }
    
    // 如果没有找到时间，添加默认时间
    if (times.isEmpty) {
      times.add(DateTime(now.year, now.month, now.day, 8, 0));
    }
    
    return times;
  }
}