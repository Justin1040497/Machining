/// 智能推荐压缩方案。
enum SmartCompressionPreset {
  balanced,
  chat,
  clear,
  compact;

  String get label {
    switch (this) {
      case SmartCompressionPreset.balanced:
        return '均衡推荐';
      case SmartCompressionPreset.chat:
        return '微信发送';
      case SmartCompressionPreset.clear:
        return '清晰优先';
      case SmartCompressionPreset.compact:
        return '体积优先';
    }
  }

  String get subtitle {
    switch (this) {
      case SmartCompressionPreset.balanced:
        return '明显变小';
      case SmartCompressionPreset.chat:
        return '聊天分享';
      case SmartCompressionPreset.clear:
        return '保留细节';
      case SmartCompressionPreset.compact:
        return '尽量压小';
    }
  }
}
