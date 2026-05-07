import 'package:machining/application/services/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/entities/media_task.dart';

class PreviewFrameFingerprint {
  final String value;

  const PreviewFrameFingerprint(this.value);

  @override
  bool operator ==(Object other) {
    return other is PreviewFrameFingerprint && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class PreviewFramePair {
  final int index;
  final double ratio;
  final double timestampSeconds;
  final String originalFramePath;
  final String previewFramePath;

  const PreviewFramePair({
    required this.index,
    required this.ratio,
    required this.timestampSeconds,
    required this.originalFramePath,
    required this.previewFramePath,
  });
}

class PreviewFrameResult {
  final String taskId;
  final String directoryPath;
  final PreviewFrameFingerprint fingerprint;
  final List<PreviewFramePair> frames;

  const PreviewFrameResult({
    required this.taskId,
    required this.directoryPath,
    required this.fingerprint,
    required this.frames,
  });

  bool isExpiredFor(PreviewFrameFingerprint currentFingerprint) {
    return fingerprint != currentFingerprint;
  }
}

class PreviewFrameRequest {
  final String ffmpegPath;
  final MediaTask task;
  final bool allowExtremeCompression;
  final FfmpegEncoderCapabilities encoderCapabilities;

  const PreviewFrameRequest({
    required this.ffmpegPath,
    required this.task,
    this.allowExtremeCompression = false,
    this.encoderCapabilities = FfmpegEncoderCapabilities.softwareOnly,
  });
}

class PreviewFrameGenerationException implements Exception {
  final String message;

  const PreviewFrameGenerationException(this.message);

  @override
  String toString() {
    return message;
  }
}

abstract class PreviewFrameGenerator {
  PreviewFrameFingerprint buildFingerprint(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  });

  Future<PreviewFrameResult> generate(PreviewFrameRequest request);
}
