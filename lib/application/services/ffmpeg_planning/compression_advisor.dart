import 'package:framelean/domain/library.dart';

enum CompressionProfile { normal, targetSize, extreme }

class CompressionRecommendation {
  final CompressionProfile profile;
  final bool sourceAlreadyCompressed;
  final bool shouldWarnUser;
  final String message;
  final int crf;
  final String preset;
  final int? targetTotalBitrate;
  final int? targetVideoBitrate;
  final int? targetAudioBitrate;
  final int? estimatedOutputSizeBytes;
  final int? bitrate;
  final int? lowBitrateThreshold;
  final CompressionBitrateSource bitrateSource;

  const CompressionRecommendation({
    required this.profile,
    required this.sourceAlreadyCompressed,
    required this.shouldWarnUser,
    required this.message,
    required this.crf,
    required this.preset,
    required this.targetTotalBitrate,
    required this.targetVideoBitrate,
    required this.targetAudioBitrate,
    required this.estimatedOutputSizeBytes,
    required this.bitrate,
    required this.lowBitrateThreshold,
    required this.bitrateSource,
  });
}

abstract class CompressionAdvisor {
  CompressionRecommendation recommend(
    MediaTask task, {
    bool allowExtremeCompression = false,
  });
}
