import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/video_codec.dart';

class FfmpegEncoderCapabilities {
  static const softwareOnly = FfmpegEncoderCapabilities(
    encoderNames: {'libx264', 'libx265'},
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
    final names = <String>{'libx264', 'libx265'};
    for (final encoderName in knownHardwareEncoderNames) {
      if (RegExp(
        r'(^|\s)' + RegExp.escape(encoderName) + r'(\s|$)',
        multiLine: true,
      ).hasMatch(output)) {
        names.add(encoderName);
      }
    }

    return FfmpegEncoderCapabilities(
      encoderNames: names,
      autoBackendPriority: autoBackendPriority,
    );
  }

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
