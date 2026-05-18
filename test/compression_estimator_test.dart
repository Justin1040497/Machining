import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/compression_estimator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';

void main() {
  group('DefaultCompressionEstimator', () {
    test('returns approximate size with a visible tolerance band', () {
      const estimator = DefaultCompressionEstimator();
      final task =
          MediaTask.draft(
                inputPath: '/videos/source.mp4',
                fileName: 'source.mp4',
                mediaKind: MediaKind.video,
                sortOrder: 0,
              )
              .withSourceFileFingerprint(
                const SourceFileFingerprint(
                  fileSize: 90 * 1024 * 1024,
                  lastModifiedAt: 1,
                ),
              )
              .withAnalysisResult(
                MediaAnalysisResult(
                  durationMs: 1125000,
                  videoWidth: 1920,
                  videoHeight: 1080,
                  videoCodec: 'h264',
                  videoBitrate: 4000000,
                  audioCodec: 'aac',
                  audioBitrate: 118000,
                ),
              );

      final estimate = estimator.estimateSmartPreset(
        task: task,
        preset: SmartCompressionPreset.compact,
        targetCodec: VideoCodec.hevc,
        targetResolutionPreset: ResolutionPreset.p720,
      );

      expect(estimate, isNotNull);
      expect(estimate!.expectedBytes, greaterThan(8 * 1024 * 1024));
      expect(estimate.expectedBytes, lessThan(18 * 1024 * 1024));
      expect(estimate.lowerBytes, lessThan(estimate.expectedBytes));
      expect(estimate.upperBytes, greaterThan(estimate.expectedBytes));
    });

    test('does not estimate output size for already compressed source', () {
      const estimator = DefaultCompressionEstimator();
      final task =
          MediaTask.draft(
                inputPath: '/videos/source.mp4',
                fileName: 'source.mp4',
                mediaKind: MediaKind.video,
                sortOrder: 0,
              )
              .withSourceFileFingerprint(
                const SourceFileFingerprint(
                  fileSize: 105 * 1024 * 1024,
                  lastModifiedAt: 1,
                ),
              )
              .withAnalysisResult(
                MediaAnalysisResult(
                  durationMs: 1125000,
                  videoWidth: 1920,
                  videoHeight: 1080,
                  videoCodec: 'h264',
                  videoBitrate: 654000,
                  audioCodec: 'aac',
                  audioBitrate: 118000,
                ),
              );

      final estimate = estimator.estimateSmartPreset(
        task: task,
        preset: SmartCompressionPreset.compact,
        targetCodec: VideoCodec.hevc,
        targetResolutionPreset: ResolutionPreset.p720,
      );

      expect(estimate, isNull);
    });

    test(
      'does not let high camera source bitrate dominate compact estimate',
      () {
        const estimator = DefaultCompressionEstimator();
        final task =
            MediaTask.draft(
                  inputPath: '/videos/dji.mp4',
                  fileName: 'dji.mp4',
                  mediaKind: MediaKind.video,
                  sortOrder: 0,
                )
                .withSourceFileFingerprint(
                  const SourceFileFingerprint(
                    fileSize: 9280 * 1024 * 1024,
                    lastModifiedAt: 1,
                  ),
                )
                .withAnalysisResult(
                  MediaAnalysisResult(
                    durationMs: 829670,
                    videoWidth: 3840,
                    videoHeight: 2160,
                    videoCodec: 'hevc',
                    videoBitrate: 87532000,
                    audioCodec: 'aac',
                    audioBitrate: 317000,
                  ),
                );

        final estimate = estimator.estimateSmartPreset(
          task: task,
          preset: SmartCompressionPreset.compact,
          targetCodec: VideoCodec.hevc,
          targetResolutionPreset: ResolutionPreset.p720,
        );

        expect(estimate, isNotNull);
        expect(estimate!.expectedBytes, lessThan(120 * 1024 * 1024));
        expect(estimate.expectedBytes, greaterThan(70 * 1024 * 1024));
      },
    );
  });
}
