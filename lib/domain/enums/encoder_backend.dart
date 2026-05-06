/// 当前任务支持的视频编码实现方式
/// VideoCodec写的是视频的编码格式
/// 而这里写的是用哪种实现方式把视频编码出来
enum EncoderBackend {
  auto,
  libx264,
  libx265,
  videotoolbox;

  String get label {
    switch (this) {
      case EncoderBackend.auto:
        return "自动选择";
      case EncoderBackend.libx264:
        return "libx264";
      case EncoderBackend.libx265:
        return "libx265";
      case EncoderBackend.videotoolbox:
        return "VideoToolbox";
    }
  }
}
