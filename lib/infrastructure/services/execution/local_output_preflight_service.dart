import 'dart:io';

import 'package:framelean/application/services/execution/output_preflight_service.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';
import 'package:path/path.dart' as path;

class LocalOutputPreflightService implements OutputPreflightService {
  LocalOutputPreflightService({FfmpegOutputPathBuilder? outputPathBuilder})
    : outputPathBuilder = outputPathBuilder ?? FfmpegOutputPathBuilder();

  final FfmpegOutputPathBuilder outputPathBuilder;

  @override
  Future<OutputPreflightResult> prepare({
    required MediaTask task,
    required FfmpegCommandPlan plan,
  }) async {
    var nextPlan = plan;
    final tags = <MediaTaskPolicyTag>{};
    final reservedPaths = <String>{};

    for (final step in plan.steps) {
      final outputPath = step.outputPath;
      if (outputPath == null) {
        continue;
      }

      final directory = Directory(path.dirname(outputPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        tags.add(MediaTaskPolicyTag.outputDirectoryCreated);
      }
      await _assertWritable(directory);

      final safePath = _uniqueSafePath(
        preferredPath: outputPath,
        inputPath: task.inputPath,
        reservedPaths: reservedPaths,
      );
      reservedPaths.add(outputPathBuilder.normalizeForComparison(safePath));

      if (safePath != outputPath) {
        tags.add(MediaTaskPolicyTag.outputRenamed);
        nextPlan = nextPlan.replaceOutputPath(
          oldPath: outputPath,
          newPath: safePath,
        );
      }
    }

    return OutputPreflightResult(plan: nextPlan, policyTags: tags);
  }

  Future<void> _assertWritable(Directory directory) async {
    final probe = File(
      path.join(
        directory.path,
        '.framelean-write-${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await probe.writeAsString('ok');
    } on Object catch (error) {
      throw StateError('输出目录不可写: ${directory.path} ($error)');
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
  }

  String _uniqueSafePath({
    required String preferredPath,
    required String inputPath,
    required Set<String> reservedPaths,
  }) {
    if (!_isUnsafePath(preferredPath, inputPath, reservedPaths)) {
      return preferredPath;
    }

    final directory = path.dirname(preferredPath);
    final baseName = path.basenameWithoutExtension(preferredPath);
    final extension = path.extension(preferredPath);

    var index = 1;
    while (true) {
      final candidate = path.join(directory, '$baseName（$index）$extension');
      if (!_isUnsafePath(candidate, inputPath, reservedPaths)) {
        return candidate;
      }
      index += 1;
    }
  }

  bool _isUnsafePath(
    String outputPath,
    String inputPath,
    Set<String> reservedPaths,
  ) {
    final normalized = outputPathBuilder.normalizeForComparison(outputPath);
    return outputPathBuilder.isSamePath(outputPath, inputPath) ||
        reservedPaths.contains(normalized) ||
        File(outputPath).existsSync();
  }
}
