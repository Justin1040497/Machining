import 'package:framelean/domain/library.dart';

extension FrameLeanCompressionModeLabel on CompressionMode {
  String get label {
    switch (this) {
      case CompressionMode.preset:
        return '推荐预设';
      case CompressionMode.targetSize:
        return '目标体积';
    }
  }
}

extension FrameLeanEncoderBackendLabel on EncoderBackend {
  String get label {
    switch (this) {
      case EncoderBackend.auto:
        return '自动选择';
      case EncoderBackend.libx264:
        return 'libx264';
      case EncoderBackend.libx265:
        return 'libx265';
      case EncoderBackend.libvpxVp9:
        return 'libvpx-vp9';
      case EncoderBackend.libsvtav1:
        return 'SVT-AV1';
      case EncoderBackend.proresKs:
        return 'ProRes KS';
      case EncoderBackend.nativeMpeg4:
        return 'MPEG-4';
      case EncoderBackend.nativeMjpeg:
        return 'MJPEG';
      case EncoderBackend.videotoolbox:
        return 'VideoToolbox';
      case EncoderBackend.nvenc:
        return 'NVIDIA NVENC';
      case EncoderBackend.qsv:
        return 'Intel Quick Sync';
      case EncoderBackend.amf:
        return 'AMD AMF';
    }
  }
}

extension FrameLeanMediaKindLabel on MediaKind {
  String get label {
    switch (this) {
      case MediaKind.video:
        return '视频';
      case MediaKind.image:
        return '图片';
      case MediaKind.audio:
        return '音频';
    }
  }
}

extension FrameLeanOutputFormatLabel on OutputFormat {
  String get label {
    switch (this) {
      case OutputFormat.mp4:
        return 'MP4';
      case OutputFormat.mov:
        return 'MOV';
      case OutputFormat.mkv:
        return 'MKV';
      case OutputFormat.webm:
        return 'WebM';
      case OutputFormat.avi:
        return 'AVI';
    }
  }
}

extension FrameLeanMediaOutputFormatLabel on MediaOutputFormat {
  String get label {
    return switch (this) {
      MediaOutputFormat.mp4 => 'MP4',
      MediaOutputFormat.mov => 'MOV',
      MediaOutputFormat.mkv => 'MKV',
      MediaOutputFormat.webm => 'WebM',
      MediaOutputFormat.avi => 'AVI',
      MediaOutputFormat.jpg => 'JPEG',
      MediaOutputFormat.png => 'PNG',
      MediaOutputFormat.webp => 'WebP',
      MediaOutputFormat.bmp => 'BMP',
      MediaOutputFormat.tiff => 'TIFF',
      MediaOutputFormat.gif => 'GIF',
      MediaOutputFormat.mp3 => 'MP3',
      MediaOutputFormat.m4a => 'M4A',
      MediaOutputFormat.aac => 'AAC',
      MediaOutputFormat.wav => 'WAV',
      MediaOutputFormat.flac => 'FLAC',
      MediaOutputFormat.aiff => 'AIFF',
      MediaOutputFormat.wma => 'WMA',
      MediaOutputFormat.opus => 'Opus',
      MediaOutputFormat.oggOpus => 'Ogg Opus',
    };
  }
}

extension FrameLeanImageResizePresetLabel on ImageResizePreset {
  String get label {
    return switch (this) {
      ImageResizePreset.original => '保持原始分辨率',
      ImageResizePreset.longEdge3840 => '3840 × 2160',
      ImageResizePreset.longEdge2560 => '2560 × 1440',
      ImageResizePreset.longEdge1920 => '1920 × 1080',
      ImageResizePreset.longEdge1280 => '1280 × 720',
      ImageResizePreset.longEdge720 => '720 × 720',
    };
  }
}

extension FrameLeanAudioBitratePresetLabel on AudioBitratePreset {
  String get label {
    return switch (this) {
      AudioBitratePreset.source => '保持原始',
      AudioBitratePreset.k320 => '320 kbps',
      AudioBitratePreset.k192 => '192 kbps',
      AudioBitratePreset.k128 => '128 kbps',
      AudioBitratePreset.k96 => '96 kbps',
      AudioBitratePreset.k64 => '64 kbps',
    };
  }
}

extension FrameLeanAudioSampleRatePresetLabel on AudioSampleRatePreset {
  String get label {
    return switch (this) {
      AudioSampleRatePreset.source => '保持原始',
      AudioSampleRatePreset.hz48000 => '48 kHz',
      AudioSampleRatePreset.hz44100 => '44.1 kHz',
      AudioSampleRatePreset.hz32000 => '32 kHz',
    };
  }
}

extension FrameLeanAudioChannelsPresetLabel on AudioChannelsPreset {
  String get label {
    return switch (this) {
      AudioChannelsPreset.source => '保持原始',
      AudioChannelsPreset.stereo => '立体声',
      AudioChannelsPreset.mono => '单声道',
    };
  }
}

extension FrameLeanResolutionPresetLabel on ResolutionPreset {
  String get label {
    switch (this) {
      case ResolutionPreset.original:
        return '保持原始';
      case ResolutionPreset.p2160:
        return '3840x2160';
      case ResolutionPreset.p1080:
        return '1920x1080';
      case ResolutionPreset.p720:
        return '1280x720';
      case ResolutionPreset.p480:
        return '854x480';
    }
  }
}

extension FrameLeanSmartCompressionPresetLabel on SmartCompressionPreset {
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

extension FrameLeanTaskPurposeLabel on TaskPurpose {
  String get label {
    switch (this) {
      case TaskPurpose.compression:
        return '文件压缩';
      case TaskPurpose.conversion:
        return '格式转换';
    }
  }
}

extension FrameLeanTaskStatusLabel on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return '等待中';
      case TaskStatus.analyzing:
        return '分析中';
      case TaskStatus.running:
        return '处理中';
      case TaskStatus.paused:
        return '已暂停';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
      case TaskStatus.cancelled:
        return '已取消';
      case TaskStatus.missingSource:
        return '源文件丢失';
    }
  }
}

extension FrameLeanVideoCodecLabel on VideoCodec {
  String get label {
    switch (this) {
      case VideoCodec.source:
        return '跟随源文件';
      case VideoCodec.h264:
        return 'H.264';
      case VideoCodec.hevc:
        return 'H.265 / HEVC';
      case VideoCodec.vp9:
        return 'VP9';
      case VideoCodec.av1:
        return 'AV1';
      case VideoCodec.proRes:
        return 'Apple ProRes';
      case VideoCodec.mpeg4:
        return 'MPEG-4 Part 2';
      case VideoCodec.mjpeg:
        return 'Motion JPEG';
    }
  }
}
