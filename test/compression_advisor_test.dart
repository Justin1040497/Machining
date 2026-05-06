import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
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
  });
}

MediaTask videoTask(MediaAnalysisResult analysisResult) {
  return MediaTask.draft(
    inputPath: '/videos/input.mp4',
    fileName: 'input.mp4',
    mediaKind: MediaKind.video,
    sortOrder: 0,
  ).withAnalysisResult(analysisResult);
}
