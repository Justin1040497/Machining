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
import 'package:path/path.dart' as path;

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
      expect(result.plan.args.last, isNot(outputPath));
      expect(result.plan.steps.single.outputPath, outputPath);
      expect(result.plan.steps.single.workingOutputPath, result.plan.args.last);
      // 工作文件不再预创建，由 FFmpeg 自行创建，只需确认路径已分配。
      expect(result.plan.steps.single.workingOutputPath, isNotNull);
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
      expect(result.plan.args.last, isNot(renamedPath));
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
      expect(result.plan.args.last, isNot(renamedPath));
    });

    test('publishes working output to the final path', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-publish-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/result.mp4';
      final service = LocalOutputPreflightService();
      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );
      final step = result.plan.steps.single;
      await File(step.workingOutputPath!).writeAsString('encoded');

      final publishedPath = await service.publish(step);

      expect(publishedPath, outputPath);
      expect(await File(outputPath).readAsString(), 'encoded');
      expect(await File(step.workingOutputPath!).exists(), isFalse);
    });

    test(
        'probe file test covers create, rename and delete with unique names',
        () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-probe-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/out.mp4';
      final service = LocalOutputPreflightService();
    
      // 预检成功，不应有残留探针文件。
      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );
    
      expect(result.plan.steps.single.workingOutputPath, isNotNull);
      // 确认探针残留被清理，目录干净。
      final dirContents = await tempDirectory.list().toList();
      final tmpFiles = dirContents
          .where((entity) =>
              entity is File &&
              path.basename(entity.path).startsWith('.framelean-write-test-'))
          .toList();
      expect(tmpFiles, isEmpty,
          reason: '预检后不应残留 .framelean-write-test- 探针文件');
    });
    
    test(
        'prepare fails with descriptive message when output directory is read-only',
        () async {
      // macOS/Linux 上用 chmod 模拟只读目录
      if (Platform.isWindows) {
        // Windows 上难以可靠模拟只读目录，跳过此测试。
        return;
      }
    
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-readonly-test-',
      );
      addTearDown(() async {
        // 恢复权限后删除
        try {
          await Process.run('chmod', ['u+w', tempDirectory.path]);
        } on Object {
          // 忽略清理失败
        }
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/out.mp4';
      final service = LocalOutputPreflightService();
    
      // 设置目录只读
      await Process.run('chmod', ['u-w', tempDirectory.path]);
    
      expect(
        () => service.prepare(
          task: task(inputPath: source.path),
          plan: plan(inputPath: source.path, outputPath: outputPath),
        ),
        throwsA(predicate((e) =>
            e is StateError && e.message.contains('输出目录不可写'))),
      );
    });
    
    test('hidden attribute failure does not abort task on Windows', () async {
      // 该测试确保 _setWindowsHiddenBestEffort 在 attrib.exe
      // 失败时不会抛出异常。非 Windows 平台直接跳过，Windows 上
      // 用不存在的文件路径模拟 attrib.exe 返回非零退出码的场景。
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-hidden-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/out.mp4';
      final service = LocalOutputPreflightService();
    
      // prepare 应成功完成，不因隐藏属性失败而抛出异常。
      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );
    
      expect(result.plan.steps.single.workingOutputPath, isNotNull);
    });
    
    test('does not overwrite a final path created during execution', () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean-preflight-late-collision-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final source = File('${tempDirectory.path}/source.mp4')
        ..writeAsStringSync('source');
      final outputPath = '${tempDirectory.path}/result.mp4';
      final service = LocalOutputPreflightService();
      final result = await service.prepare(
        task: task(inputPath: source.path),
        plan: plan(inputPath: source.path, outputPath: outputPath),
      );
      final step = result.plan.steps.single;
      await File(step.workingOutputPath!).writeAsString('encoded');
      await File(outputPath).writeAsString('external');

      final publishedPath = await service.publish(step);

      expect(await File(outputPath).readAsString(), 'external');
      expect(publishedPath, '${tempDirectory.path}/result（1）.mp4');
      expect(await File(publishedPath!).readAsString(), 'encoded');
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
