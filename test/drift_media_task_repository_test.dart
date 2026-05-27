import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_media_task_repository.dart';

void main() {
  group('DriftMediaTaskRepository mappers', () {
    test('persists extended media analysis fields from domain', () {
      final task = mediaTask(
        analysisResult: MediaAnalysisResult(
          durationMs: 1000,
          videoWidth: 1920,
          videoHeight: 1080,
          videoCodec: 'h264',
          audioCodec: 'aac',
          videoPixelFormat: 'yuv420p10le',
          videoBitDepth: 10,
          colorRange: 'tv',
          colorSpace: 'bt709',
          colorTransfer: 'bt709',
          colorPrimaries: 'bt709',
          averageFrameRate: '30000/1001',
          realFrameRate: '30000/1001',
          sampleAspectRatio: '1:1',
          displayAspectRatio: '16:9',
          videoRotationDegrees: 90,
          fieldOrder: 'progressive',
          audioChannels: 2,
          audioSampleRate: 48000,
          audioChannelLayout: 'stereo',
        ),
      );

      final companion = task.toCompanion();

      expect(companion.analysisVideoPixelFormat.value, 'yuv420p10le');
      expect(companion.analysisVideoBitDepth.value, 10);
      expect(companion.analysisColorRange.value, 'tv');
      expect(companion.analysisColorSpace.value, 'bt709');
      expect(companion.analysisColorTransfer.value, 'bt709');
      expect(companion.analysisColorPrimaries.value, 'bt709');
      expect(companion.analysisAverageFrameRate.value, '30000/1001');
      expect(companion.analysisRealFrameRate.value, '30000/1001');
      expect(companion.analysisSampleAspectRatio.value, '1:1');
      expect(companion.analysisDisplayAspectRatio.value, '16:9');
      expect(companion.analysisVideoRotationDegrees.value, 90);
      expect(companion.analysisFieldOrder.value, 'progressive');
      expect(companion.analysisAudioChannelLayout.value, 'stereo');
    });

    test('restores extended media analysis fields to domain', () {
      final row = taskRow();

      final task = row.toDomain();
      final analysis = task.analysisResult;

      expect(analysis, isNotNull);
      expect(analysis!.videoPixelFormat, 'p010le');
      expect(analysis.videoBitDepth, 10);
      expect(analysis.colorRange, 'tv');
      expect(analysis.colorSpace, 'bt2020nc');
      expect(analysis.colorTransfer, 'smpte2084');
      expect(analysis.colorPrimaries, 'bt2020');
      expect(analysis.averageFrameRate, '60000/1001');
      expect(analysis.realFrameRate, '60000/1001');
      expect(analysis.sampleAspectRatio, '1:1');
      expect(analysis.displayAspectRatio, '16:9');
      expect(analysis.videoRotationDegrees, -90);
      expect(analysis.fieldOrder, 'progressive');
      expect(analysis.audioChannelLayout, 'stereo');
      expect(analysis.isHdr, isTrue);
    });
  });
}

MediaTask mediaTask({MediaAnalysisResult? analysisResult}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    analysisResult: analysisResult,
  );
}

TaskRow taskRow() {
  return const TaskRow(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: 'video',
    purpose: 'compression',
    status: 'pending',
    progress: 0,
    sortOrder: 0,
    analysisDurationMs: 1000,
    analysisVideoWidth: 3840,
    analysisVideoHeight: 2160,
    analysisVideoCodec: 'hevc',
    analysisAudioCodec: 'aac',
    analysisVideoPixelFormat: 'p010le',
    analysisVideoBitDepth: 10,
    analysisColorRange: 'tv',
    analysisColorSpace: 'bt2020nc',
    analysisColorTransfer: 'smpte2084',
    analysisColorPrimaries: 'bt2020',
    analysisAverageFrameRate: '60000/1001',
    analysisRealFrameRate: '60000/1001',
    analysisSampleAspectRatio: '1:1',
    analysisDisplayAspectRatio: '16:9',
    analysisVideoRotationDegrees: -90,
    analysisFieldOrder: 'progressive',
    analysisAudioChannels: 2,
    analysisAudioSampleRate: 48000,
    analysisAudioChannelLayout: 'stereo',
    outputFormat: 'mp4',
    videoCodec: 'h264',
    encoderBackend: 'auto',
    resolutionPreset: 'original',
    outputDirectory: '',
    compressionCrf: 28,
    compressionMode: 'preset',
    outputFileName: '',
    createdAt: 1,
  );
}
