import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/services/execution/local_output_preflight_service.dart';

void main() {
  group('LocalOutputPreflightService', () {
    test('creates missing output directory before FFmpeg starts', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-directory-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/exports/nested/out.mp4';
      final service = LocalOutputPreflightService();

      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );

      expect(
        await Directory('${tempDirectory.path}/exports/nested').exists(),
        isTrue,
      );
      expect(
        result.policyTags,
        contains(MediaTaskPolicyTag.outputDirectoryCreated),
      );
      expect(result.plan.outputPath, outputPath);
      expect(result.plan.args.last, outputPath);
    });

    test('renames duplicate output and rewrites command args', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-rename-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/source_compressed.mp4';
      File(outputPath).writeAsStringSync('existing');
      final service = LocalOutputPreflightService();

      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );

      final renamedPath = '${tempDirectory.path}/source_compressed（1）.mp4';
      expect(result.policyTags, contains(MediaTaskPolicyTag.outputRenamed));
      expect(result.plan.outputPath, renamedPath);
      expect(result.plan.steps.single.outputPath, renamedPath);
      expect(result.plan.args.last, renamedPath);
    });

    test('renames output that would overwrite the source file', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-source-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final service = LocalOutputPreflightService();

      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: source.path),
      );

      final renamedPath = '${tempDirectory.path}/source（1）.mp4';
      expect(result.policyTags, contains(MediaTaskPolicyTag.outputRenamed));
      expect(result.plan.outputPath, renamedPath);
      expect(result.plan.args.last, renamedPath);
    });
  });
}

MediaTask task({required String inputPath}) {
  return MediaTask(
    id: 'task-1',
    inputPath: inputPath,
    fileName: inputPath.split('/').last,
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
  );
}

FfmpegCommandPlan plan({
  required String inputPath,
  required String outputPath,
}) {
  final args = ['-hide_banner', '-i', inputPath, outputPath];
  return FfmpegCommandPlan(
    args: args,
    outputPath: outputPath,
    logHint: 'preflight test',
  );
}
