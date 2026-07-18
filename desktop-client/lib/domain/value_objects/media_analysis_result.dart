import 'package:framelean/domain/value_objects/media_audio_stream_info.dart';

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

  /// 视频像素格式和位深，例如 yuv420p、p010le、10
  final String? videoPixelFormat;
  final int? videoBitDepth;

  /// 视频色彩信息
  final String? colorRange;
  final String? colorSpace;
  final String? colorTransfer;
  final String? colorPrimaries;
  final String? chromaLocation;
  final String? masteringDisplayMetadata;
  final double? masteringDisplayMaxLuminance;
  final int? maxContentLightLevel;
  final int? maxFrameAverageLightLevel;
  final int? dolbyVisionProfile;
  final int? dolbyVisionCompatibilityId;

  /// 帧率和显示比例信息
  final String? averageFrameRate;
  final String? realFrameRate;
  final String? sampleAspectRatio;
  final String? displayAspectRatio;

  /// 视频方向和扫描方式
  final int? videoRotationDegrees;
  final String? fieldOrder;

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

  /// 音频声道布局，例如 mono、stereo、5.1(side)
  final String? audioChannelLayout;

  /// 可转码主音频流在 FFprobe `streams` 中的全局索引。
  final int? audioStreamIndex;

  /// FFprobe 识别出的可转码音频流列表。
  final List<MediaAudioStreamInfo> audioStreams;

  /// 静态图片宽高和编码信息。
  final int? imageWidth;
  final int? imageHeight;
  final String? imageCodec;
  final String? imagePixelFormat;
  final int? imageBitDepth;
  final int? orientationDegrees;

  MediaAnalysisResult({
    this.durationMs,
    this.videoWidth,
    this.videoHeight,
    this.videoCodec,
    this.audioCodec,
    this.videoPixelFormat,
    this.videoBitDepth,
    this.colorRange,
    this.colorSpace,
    this.colorTransfer,
    this.colorPrimaries,
    this.chromaLocation,
    this.masteringDisplayMetadata,
    this.masteringDisplayMaxLuminance,
    this.maxContentLightLevel,
    this.maxFrameAverageLightLevel,
    this.dolbyVisionProfile,
    this.dolbyVisionCompatibilityId,
    this.averageFrameRate,
    this.realFrameRate,
    this.sampleAspectRatio,
    this.displayAspectRatio,
    this.videoRotationDegrees,
    this.fieldOrder,
    this.videoBitrate,
    this.audioBitrate,
    this.containerBitrate,
    this.estimatedBitrate,
    this.containerFormat,
    this.audioChannels,
    this.audioSampleRate,
    this.audioChannelLayout,
    this.audioStreamIndex,
    this.audioStreams = const [],
    this.imageWidth,
    this.imageHeight,
    this.imageCodec,
    this.imagePixelFormat,
    this.imageBitDepth,
    this.orientationDegrees,
  });

  MediaAnalysisResult copyWith({
    int? durationMs,
    int? videoWidth,
    int? videoHeight,
    String? videoCodec,
    String? audioCodec,
    String? videoPixelFormat,
    int? videoBitDepth,
    String? colorRange,
    String? colorSpace,
    String? colorTransfer,
    String? colorPrimaries,
    String? chromaLocation,
    String? masteringDisplayMetadata,
    double? masteringDisplayMaxLuminance,
    int? maxContentLightLevel,
    int? maxFrameAverageLightLevel,
    int? dolbyVisionProfile,
    int? dolbyVisionCompatibilityId,
    String? averageFrameRate,
    String? realFrameRate,
    String? sampleAspectRatio,
    String? displayAspectRatio,
    int? videoRotationDegrees,
    String? fieldOrder,
    int? videoBitrate,
    int? audioBitrate,
    int? containerBitrate,
    int? estimatedBitrate,
    String? containerFormat,
    int? audioChannels,
    int? audioSampleRate,
    String? audioChannelLayout,
    int? audioStreamIndex,
    List<MediaAudioStreamInfo>? audioStreams,
    int? imageWidth,
    int? imageHeight,
    String? imageCodec,
    String? imagePixelFormat,
    int? imageBitDepth,
    int? orientationDegrees,
  }) {
    return MediaAnalysisResult(
      durationMs: durationMs ?? this.durationMs,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      videoPixelFormat: videoPixelFormat ?? this.videoPixelFormat,
      videoBitDepth: videoBitDepth ?? this.videoBitDepth,
      colorRange: colorRange ?? this.colorRange,
      colorSpace: colorSpace ?? this.colorSpace,
      colorTransfer: colorTransfer ?? this.colorTransfer,
      colorPrimaries: colorPrimaries ?? this.colorPrimaries,
      chromaLocation: chromaLocation ?? this.chromaLocation,
      masteringDisplayMetadata:
          masteringDisplayMetadata ?? this.masteringDisplayMetadata,
      masteringDisplayMaxLuminance:
          masteringDisplayMaxLuminance ?? this.masteringDisplayMaxLuminance,
      maxContentLightLevel: maxContentLightLevel ?? this.maxContentLightLevel,
      maxFrameAverageLightLevel:
          maxFrameAverageLightLevel ?? this.maxFrameAverageLightLevel,
      dolbyVisionProfile: dolbyVisionProfile ?? this.dolbyVisionProfile,
      dolbyVisionCompatibilityId:
          dolbyVisionCompatibilityId ?? this.dolbyVisionCompatibilityId,
      averageFrameRate: averageFrameRate ?? this.averageFrameRate,
      realFrameRate: realFrameRate ?? this.realFrameRate,
      sampleAspectRatio: sampleAspectRatio ?? this.sampleAspectRatio,
      displayAspectRatio: displayAspectRatio ?? this.displayAspectRatio,
      videoRotationDegrees: videoRotationDegrees ?? this.videoRotationDegrees,
      fieldOrder: fieldOrder ?? this.fieldOrder,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      containerBitrate: containerBitrate ?? this.containerBitrate,
      estimatedBitrate: estimatedBitrate ?? this.estimatedBitrate,
      containerFormat: containerFormat ?? this.containerFormat,
      audioChannels: audioChannels ?? this.audioChannels,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannelLayout: audioChannelLayout ?? this.audioChannelLayout,
      audioStreamIndex: audioStreamIndex ?? this.audioStreamIndex,
      audioStreams: audioStreams ?? this.audioStreams,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      imageCodec: imageCodec ?? this.imageCodec,
      imagePixelFormat: imagePixelFormat ?? this.imagePixelFormat,
      imageBitDepth: imageBitDepth ?? this.imageBitDepth,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
    );
  }

  /// 压缩策略判断使用的有效码率。顺序必须和白板一致：
  /// 1. videoStream.bit_rate
  /// 2. format.bit_rate
  /// 3. fileSize * 8 / durationSeconds
  int? get preferredBitrate =>
      videoBitrate ?? audioBitrate ?? containerBitrate ?? estimatedBitrate;

  bool get isHdr {
    final transfer = colorTransfer?.trim().toLowerCase();
    final space = colorSpace?.trim().toLowerCase();
    final primaries = colorPrimaries?.trim().toLowerCase();
    return transfer == 'smpte2084' ||
        transfer == 'arib-std-b67' ||
        space == 'bt2020nc' ||
        space == 'bt2020ncl' ||
        primaries == 'bt2020';
  }

  bool get isUnsupportedDolbyVisionProfile {
    return dolbyVisionProfile == 5 ||
        (dolbyVisionProfile == 10 && dolbyVisionCompatibilityId == 0);
  }
}
