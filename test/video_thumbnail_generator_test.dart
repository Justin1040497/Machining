import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/execution/video_thumbnail_generator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/infrastructure/services/execution/local_video_thumbnail_generator.dart';
import 'package:path/path.dart' as path;

void main() {
  group('LocalVideoThumbnailGenerator', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'machining_thumbnail_test_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('detects all-black raw frames', () {
      const generator = LocalVideoThumbnailGenerator();

      expect(generator.isBlackFrame(Uint8ListFixture.blackFrame), true);
      expect(generator.isBlackFrame(Uint8ListFixture.visibleFrame), false);
    });

    test('skips black frames and extracts the first visible frame', () async {
      final probedTimestamps = <String>[];
      final extractedTimestamps = <String>[];
      final outputPath = path.join(tempDirectory.path, 'thumb.jpg');
      final generator = LocalVideoThumbnailGenerator(
        runProbe: ({required ffmpegPath, required args}) async {
          final timestamp = args[args.indexOf('-ss') + 1];
          probedTimestamps.add(timestamp);
          return VideoThumbnailProbeResult(
            exitCode: 0,
            bytes: probedTimestamps.length == 1
                ? Uint8ListFixture.blackFrame
                : Uint8ListFixture.visibleFrame,
          );
        },
        runCommand: ({required ffmpegPath, required args}) async {
          extractedTimestamps.add(args[args.indexOf('-ss') + 1]);
          await File(args.last).create(recursive: true);
          return const VideoThumbnailCommandResult(exitCode: 0);
        },
      );

      final result = await generator.generate(
        VideoThumbnailRequest(
          ffmpegPath: '/usr/bin/ffmpeg',
          task: videoTask(),
          outputPath: outputPath,
        ),
      );

      expect(probedTimestamps, ['0.100', '5.000']);
      expect(extractedTimestamps, ['5.000']);
      expect(result.outputPath, outputPath);
      expect(result.timestampSeconds, 5);
      expect(await File(outputPath).exists(), true);
    });

    test('throws when every candidate frame is black', () async {
      final generator = LocalVideoThumbnailGenerator(
        runProbe: ({required ffmpegPath, required args}) async {
          return VideoThumbnailProbeResult(
            exitCode: 0,
            bytes: Uint8ListFixture.blackFrame,
          );
        },
      );

      expect(
        () => generator.generate(
          VideoThumbnailRequest(
            ffmpegPath: '/usr/bin/ffmpeg',
            task: videoTask(),
            outputPath: path.join(tempDirectory.path, 'thumb.jpg'),
          ),
        ),
        throwsA(isA<VideoThumbnailGenerationException>()),
      );
    });
  });
}

class Uint8ListFixture {
  static final blackFrame = Uint8List.fromList(
    List<int>.filled(
      LocalVideoThumbnailGenerator.probeSize *
          LocalVideoThumbnailGenerator.probeSize *
          3,
      0,
    ),
  );

  static final visibleFrame = Uint8List.fromList(
    List<int>.filled(
      LocalVideoThumbnailGenerator.probeSize *
          LocalVideoThumbnailGenerator.probeSize *
          3,
      0,
    ),
  )..setRange(0, 24, List<int>.filled(24, 220));
}

MediaTask videoTask() {
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
    analysisResult: MediaAnalysisResult(
      durationMs: 100000,
      videoWidth: 1920,
      videoHeight: 1080,
      videoCodec: 'h264',
      videoBitrate: 3000000,
      audioBitrate: 128000,
    ),
  );
}
