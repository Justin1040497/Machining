import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/infrastructure/services/default_compression_advisor.dart';

void main() {
  group('DefaultCompressionAdvisor', () {
    test('prefers video bitrate over container and estimated bitrate', () {
      final advisor = DefaultCompressionAdvisor();
      final task = videoTask(
        MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 900000,
          containerBitrate: 5000000,
          estimatedBitrate: 6000000,
        ),
      );

      final recommendation = advisor.recommend(task);

      expect(recommendation.bitrate, 900000);
      expect(
        recommendation.bitrateSource,
        CompressionBitrateSource.videoStream,
      );
      expect(recommendation.shouldWarnUser, isTrue);
    });

    test('uses container bitrate when video bitrate is missing', () {
      final advisor = DefaultCompressionAdvisor();
      final task = videoTask(
        MediaAnalysisResult(videoHeight: 1080, containerBitrate: 2000000),
      );

      final recommendation = advisor.recommend(task);

      expect(recommendation.bitrate, 2000000);
      expect(recommendation.bitrateSource, CompressionBitrateSource.container);
      expect(recommendation.shouldWarnUser, isFalse);
      expect(recommendation.crf, 28);
    });

    test('uses estimated bitrate when direct bitrate fields are missing', () {
      final advisor = DefaultCompressionAdvisor();
      final task = videoTask(
        MediaAnalysisResult(videoHeight: 720, estimatedBitrate: 500000),
      );

      final recommendation = advisor.recommend(task);

      expect(recommendation.bitrate, 500000);
      expect(recommendation.bitrateSource, CompressionBitrateSource.estimated);
      expect(recommendation.shouldWarnUser, isTrue);
    });

    test(
      'returns target bitrate extreme compression after user confirmation',
      () {
        final advisor = DefaultCompressionAdvisor();
        final task = videoTask(
          MediaAnalysisResult(
            videoHeight: 1080,
            videoBitrate: 550000,
            audioBitrate: 128000,
          ),
        );

        final recommendation = advisor.recommend(
          task,
          allowExtremeCompression: true,
        );

        expect(recommendation.profile, CompressionProfile.extreme);
        expect(recommendation.crf, 30);
        expect(recommendation.targetTotalBitrate, 467500);
        expect(recommendation.targetAudioBitrate, 64000);
        expect(recommendation.targetVideoBitrate, 403500);
        expect(recommendation.shouldWarnUser, isFalse);
      },
    );

    test('caps smart bitrate for high bitrate camera footage', () {
      final advisor = DefaultCompressionAdvisor();
      final task = videoTask(
        MediaAnalysisResult(
          videoHeight: 2160,
          videoBitrate: 90000000,
          audioBitrate: 317000,
        ),
        config: VideoTaskConfig.initial().copyWith(
          compressionMode: CompressionMode.smart,
          smartPreset: SmartCompressionPreset.compact,
          videoCodec: VideoCodec.hevc,
          resolutionPreset: ResolutionPreset.p720,
        ),
      );

      final recommendation = advisor.recommend(task);

      expect(recommendation.profile, CompressionProfile.normal);
      expect(recommendation.targetVideoBitrate, 792000);
      expect(recommendation.targetAudioBitrate, 48000);
      expect(recommendation.targetTotalBitrate, 840000);
    });

    test('calculates target bitrate from target size bytes', () {
      final advisor = DefaultCompressionAdvisor();
      final task = videoTask(
        MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 5000000,
          audioBitrate: 192000,
          durationMs: 100000,
        ),
        config: VideoTaskConfig.initial().copyWith(
          compressionMode: CompressionMode.targetSize,
          targetSizeBytes: 50000000,
        ),
        sourceFileSize: 100000000,
      );

      final recommendation = advisor.recommend(task);

      expect(recommendation.profile, CompressionProfile.targetSize);
      expect(recommendation.targetTotalBitrate, 4000000);
      expect(recommendation.targetAudioBitrate, 128000);
      expect(recommendation.targetVideoBitrate, 3872000);
      expect(recommendation.estimatedOutputSizeBytes, 50000000);
      expect(recommendation.shouldWarnUser, isFalse);
    });

    test(
      'does not silently raise strict target size to resolution minimum',
      () {
        final advisor = DefaultCompressionAdvisor();
        final task = videoTask(
          MediaAnalysisResult(
            videoHeight: 720,
            videoBitrate: 654000,
            audioBitrate: 118000,
            audioCodec: 'aac',
            durationMs: 1125000,
          ),
          config: VideoTaskConfig.initial().copyWith(
            compressionMode: CompressionMode.targetSize,
            targetSizeBytes: 10 * 1024 * 1024,
          ),
          sourceFileSize: 105 * 1024 * 1024,
        );

        final recommendation = advisor.recommend(task);

        expect(recommendation.profile, CompressionProfile.targetSize);
        expect(recommendation.targetTotalBitrate, lessThan(100000));
        expect(recommendation.targetVideoBitrate, lessThan(60000));
        expect(recommendation.targetAudioBitrate, 24000);
        expect(
          recommendation.estimatedOutputSizeBytes,
          lessThan(11 * 1024 * 1024),
        );
      },
    );
  });
}

MediaTask videoTask(
  MediaAnalysisResult analysisResult, {
  VideoTaskConfig? config,
  int? sourceFileSize,
}) {
  var task = MediaTask.draft(
    inputPath: '/videos/input.mp4',
    fileName: 'input.mp4',
    mediaKind: MediaKind.video,
    sortOrder: 0,
    config: config,
  );

  if (sourceFileSize != null) {
    task = task.withSourceFileFingerprint(
      SourceFileFingerprint(fileSize: sourceFileSize, lastModifiedAt: 1),
    );
  }

  return task.withAnalysisResult(analysisResult);
}
