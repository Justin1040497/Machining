/// HDR 视频输出策略。
enum HdrOutputMode {
  /// 默认把 HDR 源转换成 SDR，兼容更多播放器。
  convertToSdr,

  /// 保持 HDR10 / HLG 的 10-bit 输出和基础色彩标记。
  preserveHdr,
}
