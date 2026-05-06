/// 媒体文件分析结果 Ffprobe分析结果
class MediaAnalysisResult {
  /// 预计使用时长
  final int? durationMs;

  /// 视频宽高
  final int? videoWidth;
  final int? videoHeight;

  /// 视频编码和音频编码
  final String? videoCodec;
  final String? audioCodec;

  /// 视频流码率，优先从 videoStream.bit_rate 读取，单位 bps
  final int? videoBitrate;

  /// 音频流码率，从 audioStream.bit_rate 读取，单位 bps
  final int? audioBitrate;

  /// 容器总码率，从 format.bit_rate 读取，单位 bps
  final int? containerBitrate;

  /// 估算平均码率，用 fileSize * 8 / durationSeconds 得到，单位 bps
  final int? estimatedBitrate;

  /// 视频封装格式：mp4、mov、mkv
  final String? containerFormat;

  /// 表示音频声道数 1=单声道 2=立体声
  final int? audioChannels;

  /// 音频采样率 44100 48000
  final int? audioSampleRate;

  MediaAnalysisResult({
    this.durationMs,
    this.videoWidth,
    this.videoHeight,
    this.videoCodec,
    this.audioCodec,
    this.videoBitrate,
    this.audioBitrate,
    this.containerBitrate,
    this.estimatedBitrate,
    this.containerFormat,
    this.audioChannels,
    this.audioSampleRate,
  });

  MediaAnalysisResult copyWith({
    int? durationMs,
    int? videoWidth,
    int? videoHeight,
    String? videoCodec,
    String? audioCodec,
    int? videoBitrate,
    int? audioBitrate,
    int? containerBitrate,
    int? estimatedBitrate,
    String? containerFormat,
    int? audioChannels,
    int? audioSampleRate,
  }) {
    return MediaAnalysisResult(
      durationMs: durationMs ?? this.durationMs,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      containerBitrate: containerBitrate ?? this.containerBitrate,
      estimatedBitrate: estimatedBitrate ?? this.estimatedBitrate,
      containerFormat: containerFormat ?? this.containerFormat,
      audioChannels: audioChannels ?? this.audioChannels,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
    );
  }

  /// 压缩策略判断使用的有效码率。顺序必须和白板一致：
  /// 1. videoStream.bit_rate
  /// 2. format.bit_rate
  /// 3. fileSize * 8 / durationSeconds
  int? get preferredBitrate =>
      videoBitrate ?? containerBitrate ?? estimatedBitrate;
}
