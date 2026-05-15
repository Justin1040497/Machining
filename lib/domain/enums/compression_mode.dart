/// 当前任务的视频压缩控制方式
enum CompressionMode {
  /// 智能推荐方案，输出体积只做预估，不做强承诺。
  smart,

  /// 质量优先，用 CRF 控制画质，输出体积不做强承诺。
  quality,

  /// 指定目标体积，用目标码率尽量接近用户选择的体积。
  targetSize;

  String get label {
    switch (this) {
      case CompressionMode.smart:
        return '智能推荐';
      case CompressionMode.quality:
        return '质量优先';
      case CompressionMode.targetSize:
        return '目标体积';
    }
  }
}
