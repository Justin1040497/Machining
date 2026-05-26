import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/execution/preview_frame_generator.dart';
import 'package:machining/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/infrastructure/services/execution/local_preview_frame_generator.dart';
import 'package:machining/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';
import 'package:path/path.dart' as path;

void main() {
  group('LocalPreviewFrameGenerator', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'machining_preview_test_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'generates five original and compressed preview frame pairs',
      () async {
        final commands = <List<String>>[];
        final task = videoTask();
        final generator = LocalPreviewFrameGenerator(
          commandBuilder: DefaultFfmpegCommandBuilder(pathExists: (_) => false),
          compressionAdvisor: DefaultCompressionAdvisor(),
          previewDirectoryFactory: (_) =>
              Directory(path.join(tempDirectory.path, 'previews', task.id)),
          runCommand: ({required ffmpegPath, required args}) async {
            commands.add(args);
            await File(args.last).create(recursive: true);
            return const PreviewFrameCommandResult(exitCode: 0);
          },
        );

        final result = await generator.generate(
          PreviewFrameRequest(ffmpegPath: '/usr/bin/ffmpeg', task: task),
        );

        expect(result.frames, hasLength(5));
        expect(result.frames.map((frame) => frame.ratio), [
          0.05,
          0.275,
          0.5,
          0.725,
          0.95,
        ]);
        expect(result.frames.first.timestampSeconds, 5);
        expect(result.frames.last.timestampSeconds, 95);
        expect(commands, hasLength(15));
        expect(commands.first, containsAllInOrder(['-ss', '5.000']));
        expect(commands[1], containsAllInOrder(['-t', '1.000']));
        expect(commands[1], containsAllInOrder(['-c:v', 'libx264']));
        expect(commands[1], isNot(contains('-progress')));
        expect(commands[2], containsAllInOrder(['-ss', '0.500']));
        expect(
          await File(result.frames.first.originalFramePath).exists(),
          true,
        );
        expect(await File(result.frames.first.previewFramePath).exists(), true);
        expect(
          await File(
            path.join(result.directoryPath, 'preview_segment_1.mp4'),
          ).exists(),
          false,
        );
      },
    );

    test('rejects tasks without media duration', () async {
      final generator = LocalPreviewFrameGenerator(
        commandBuilder: DefaultFfmpegCommandBuilder(pathExists: (_) => false),
        compressionAdvisor: DefaultCompressionAdvisor(),
        previewDirectoryFactory: (_) => tempDirectory,
        runCommand: ({required ffmpegPath, required args}) async {
          return const PreviewFrameCommandResult(exitCode: 0);
        },
      );

      expect(
        () => generator.generate(
          PreviewFrameRequest(
            ffmpegPath: '/usr/bin/ffmpeg',
            task: videoTask(analysisResult: MediaAnalysisResult()),
          ),
        ),
        throwsA(isA<PreviewFrameGenerationException>()),
      );
    });

    test('marks result expired after compression parameters change', () async {
      final commands = <List<String>>[];
      final task = videoTask();
      final generator = LocalPreviewFrameGenerator(
        commandBuilder: DefaultFfmpegCommandBuilder(pathExists: (_) => false),
        compressionAdvisor: DefaultCompressionAdvisor(),
        previewDirectoryFactory: (_) =>
            Directory(path.join(tempDirectory.path, 'previews', task.id)),
        runCommand: ({required ffmpegPath, required args}) async {
          commands.add(args);
          await File(args.last).create(recursive: true);
          return const PreviewFrameCommandResult(exitCode: 0);
        },
      );

      final result = await generator.generate(
        PreviewFrameRequest(ffmpegPath: '/usr/bin/ffmpeg', task: task),
      );
      final changedTask = task.copyWith(
        config: task.config.copyWith(videoCodec: VideoCodec.hevc),
      );

      expect(result.isExpiredFor(generator.buildFingerprint(task)), false);
      expect(
        result.isExpiredFor(generator.buildFingerprint(changedTask)),
        true,
      );
    });

    test('reports ffmpeg command failures', () async {
      final generator = LocalPreviewFrameGenerator(
        commandBuilder: DefaultFfmpegCommandBuilder(pathExists: (_) => false),
        compressionAdvisor: DefaultCompressionAdvisor(),
        previewDirectoryFactory: (_) => tempDirectory,
        runCommand: ({required ffmpegPath, required args}) async {
          return const PreviewFrameCommandResult(
            exitCode: 1,
            stderr: 'bad frame',
          );
        },
      );

      expect(
        () => generator.generate(
          PreviewFrameRequest(ffmpegPath: '/usr/bin/ffmpeg', task: videoTask()),
        ),
        throwsA(
          isA<PreviewFrameGenerationException>().having(
            (error) => error.message,
            'message',
            contains('bad frame'),
          ),
        ),
      );
    });

    test(
      'deletes preview segment when compressed frame extraction fails',
      () async {
        var commandIndex = 0;
        late Directory previewDirectory;
        final task = videoTask();
        final generator = LocalPreviewFrameGenerator(
          commandBuilder: DefaultFfmpegCommandBuilder(pathExists: (_) => false),
          compressionAdvisor: DefaultCompressionAdvisor(),
          previewDirectoryFactory: (_) {
            previewDirectory = Directory(
              path.join(tempDirectory.path, 'previews', task.id),
            );
            return previewDirectory;
          },
          runCommand: ({required ffmpegPath, required args}) async {
            commandIndex += 1;
            await File(args.last).create(recursive: true);
            if (commandIndex == 3) {
              return const PreviewFrameCommandResult(
                exitCode: 1,
                stderr: 'extract failed',
              );
            }

            return const PreviewFrameCommandResult(exitCode: 0);
          },
        );

        await expectLater(
          generator.generate(
            PreviewFrameRequest(ffmpegPath: '/usr/bin/ffmpeg', task: task),
          ),
          throwsA(isA<PreviewFrameGenerationException>()),
        );

        expect(
          await File(
            path.join(previewDirectory.path, 'preview_segment_1.mp4'),
          ).exists(),
          false,
        );
      },
    );
  });
}

MediaTask videoTask({MediaAnalysisResult? analysisResult}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial().copyWith(videoCodec: VideoCodec.h264),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    analysisResult:
        analysisResult ??
        MediaAnalysisResult(
          durationMs: 100000,
          videoWidth: 1920,
          videoHeight: 1080,
          videoCodec: 'h264',
          videoBitrate: 3000000,
          audioBitrate: 128000,
        ),
  );
}
