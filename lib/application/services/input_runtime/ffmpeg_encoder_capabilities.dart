import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/video_codec.dart';

class FfmpegEncoderCapabilities {
  static const softwareOnly = FfmpegEncoderCapabilities(
    encoderNames: {
      'libx264',
      'libx265',
      'libmp3lame',
      'aac',
      'libopus',
      'pcm_s16le',
      'pcm_s24le',
      'flac',
      'pcm_s16be',
      'pcm_s24be',
      'wmav2',
      'libwebp',
      'prores_ks',
    },
    autoBackendPriority: [],
  );

  final Set<String> encoderNames;
  final List<EncoderBackend> autoBackendPriority;

  const FfmpegEncoderCapabilities({
    required this.encoderNames,
    required this.autoBackendPriority,
  });

  String get fingerprintValue {
    final sortedNames = encoderNames.toList()..sort();
    return [
      sortedNames.join(','),
      autoBackendPriority.map((backend) => backend.name).join(','),
    ].join('|');
  }

  factory FfmpegEncoderCapabilities.fromEncodersOutput(
    String output, {
    required List<EncoderBackend> autoBackendPriority,
  }) {
    final names = <String>{};
    for (final encoderName in knownSoftwareEncoderNames) {
      if (encoderOutputContainsName(output, encoderName)) {
        names.add(encoderName);
      }
    }

    for (final encoderName in knownHardwareEncoderNames) {
      if (encoderOutputContainsName(output, encoderName)) {
        names.add(encoderName);
      }
    }

    for (final encoderName in knownAudioEncoderNames) {
      if (encoderOutputContainsName(output, encoderName)) {
        names.add(encoderName);
      }
    }

    for (final encoderName in knownImageEncoderNames) {
      if (encoderOutputContainsName(output, encoderName)) {
        names.add(encoderName);
      }
    }

    return FfmpegEncoderCapabilities(
      encoderNames: names,
      autoBackendPriority: autoBackendPriority,
    );
  }

  static bool encoderOutputContainsName(String output, String encoderName) {
    return RegExp(
      r'(^|\s)' + RegExp.escape(encoderName) + r'(\s|$)',
      multiLine: true,
    ).hasMatch(output);
  }

  static const knownSoftwareEncoderNames = <String>{
    'libx264',
    'libx265',
    'prores_ks',
  };

  static const knownAudioEncoderNames = <String>{
    'libmp3lame',
    'aac',
    'aac_at',
    'libopus',
    'pcm_s16le',
    'pcm_s24le',
    'flac',
    'pcm_s16be',
    'pcm_s24be',
    'wmav2',
  };

  static const knownImageEncoderNames = <String>{'libwebp'};

  static const knownHardwareEncoderNames = <String>{
    'h264_videotoolbox',
    'hevc_videotoolbox',
    'h264_nvenc',
    'hevc_nvenc',
    'h264_qsv',
    'hevc_qsv',
    'h264_amf',
    'hevc_amf',
  };

  static const knownEncoderNames = <String>{
    ...knownSoftwareEncoderNames,
    ...knownHardwareEncoderNames,
    ...knownAudioEncoderNames,
    ...knownImageEncoderNames,
  };

  factory FfmpegEncoderCapabilities.assumeBundledFallback({
    required List<EncoderBackend> autoBackendPriority,
  }) {
    return FfmpegEncoderCapabilities(
      encoderNames: const {
        'libx264',
        'libmp3lame',
        'aac',
        'libopus',
        'pcm_s16le',
        'pcm_s24le',
        'flac',
        'pcm_s16be',
        'pcm_s24be',
        'wmav2',
        'libwebp',
        'prores_ks',
      },
      autoBackendPriority: autoBackendPriority,
    );
  }

  bool supportsAudioEncoder(String encoderName) {
    return knownAudioEncoderNames.contains(encoderName) &&
        encoderNames.contains(encoderName);
  }

  bool supportsImageEncoder(String encoderName) {
    return knownImageEncoderNames.contains(encoderName) &&
        encoderNames.contains(encoderName);
  }

  String resolveEncoderName({
    required VideoCodec targetCodec,
    required EncoderBackend backend,
  }) {
    final resolvedBackend = backend == EncoderBackend.auto
        ? resolveAutoBackend(targetCodec)
        : backend;
    final encoderName = encoderNameFor(
      targetCodec: targetCodec,
      backend: resolvedBackend,
    );

    if (encoderName == null) {
      throw IncompatibleEncoderBackendException(
        targetCodec: targetCodec,
        backend: resolvedBackend,
      );
    }

    if (!encoderNames.contains(encoderName)) {
      throw UnsupportedEncoderBackendException(
        encoderName: encoderName,
        backend: resolvedBackend,
      );
    }

    return encoderName;
  }

  bool supportsEncoder({
    required VideoCodec targetCodec,
    required EncoderBackend backend,
  }) {
    final encoderName = encoderNameFor(
      targetCodec: targetCodec,
      backend: backend,
    );
    return encoderName != null && encoderNames.contains(encoderName);
  }

  EncoderBackend resolveAutoBackend(VideoCodec targetCodec) {
    for (final backend in autoBackendPriority) {
      final encoderName = encoderNameFor(
        targetCodec: targetCodec,
        backend: backend,
      );
      if (encoderName != null && encoderNames.contains(encoderName)) {
        return backend;
      }
    }

    return switch (targetCodec) {
      VideoCodec.h264 => EncoderBackend.libx264,
      VideoCodec.hevc => EncoderBackend.libx265,
      VideoCodec.source => throw const SourceCodecNotResolvedException(),
    };
  }

  bool isHardwareEncoder(String encoderName) {
    return knownHardwareEncoderNames.contains(encoderName);
  }

  static String? encoderNameFor({
    required VideoCodec targetCodec,
    required EncoderBackend backend,
  }) {
    return switch ((targetCodec, backend)) {
      (VideoCodec.h264, EncoderBackend.libx264) => 'libx264',
      (VideoCodec.hevc, EncoderBackend.libx265) => 'libx265',
      (VideoCodec.h264, EncoderBackend.videotoolbox) => 'h264_videotoolbox',
      (VideoCodec.hevc, EncoderBackend.videotoolbox) => 'hevc_videotoolbox',
      (VideoCodec.h264, EncoderBackend.nvenc) => 'h264_nvenc',
      (VideoCodec.hevc, EncoderBackend.nvenc) => 'hevc_nvenc',
      (VideoCodec.h264, EncoderBackend.qsv) => 'h264_qsv',
      (VideoCodec.hevc, EncoderBackend.qsv) => 'hevc_qsv',
      (VideoCodec.h264, EncoderBackend.amf) => 'h264_amf',
      (VideoCodec.hevc, EncoderBackend.amf) => 'hevc_amf',
      (VideoCodec.source, _) => throw const SourceCodecNotResolvedException(),
      _ => null,
    };
  }
}

class SourceCodecNotResolvedException implements Exception {
  const SourceCodecNotResolvedException();
}

class IncompatibleEncoderBackendException implements Exception {
  final VideoCodec targetCodec;
  final EncoderBackend backend;

  const IncompatibleEncoderBackendException({
    required this.targetCodec,
    required this.backend,
  });
}

class UnsupportedEncoderBackendException implements Exception {
  final String encoderName;
  final EncoderBackend backend;

  const UnsupportedEncoderBackendException({
    required this.encoderName,
    required this.backend,
  });
}
