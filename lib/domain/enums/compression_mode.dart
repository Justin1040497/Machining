/// 当前任务的视频压缩控制方式
enum CompressionMode {
  /// 推荐预设方案，输出体积只做预估，不做强承诺。
  preset,

  /// 指定目标体积，用目标码率尽量接近用户选择的体积。
  targetSize,
}
