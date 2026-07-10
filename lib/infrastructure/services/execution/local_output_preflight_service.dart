import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';
import 'package:path/path.dart' as path;

class LocalOutputPreflightService implements OutputPreflightService {
  LocalOutputPreflightService({FfmpegOutputPathBuilder? outputPathBuilder})
    : outputPathBuilder = outputPathBuilder ?? FfmpegOutputPathBuilder();

  final FfmpegOutputPathBuilder outputPathBuilder;
  final Set<String> _reservedFinalPaths = <String>{};

  @override
  Future<OutputPreflightResult> prepare({
    required MediaTask task,
    required FfmpegCommandPlan plan,
  }) async {
    var nextPlan = plan;
    final tags = <MediaTaskPolicyTag>{};
    final reservedPaths = <String>{};
    final preparedSteps = <FfmpegCommandStep>[];

    try {
      for (var stepIndex = 0; stepIndex < plan.steps.length; stepIndex += 1) {
        final step = plan.steps[stepIndex];
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
          reservedPaths: {..._reservedFinalPaths, ...reservedPaths},
        );
        final normalizedSafePath = outputPathBuilder.normalizeForComparison(
          safePath,
        );
        reservedPaths.add(normalizedSafePath);
        _reservedFinalPaths.add(normalizedSafePath);

        if (safePath != outputPath) {
          tags.add(MediaTaskPolicyTag.outputRenamed);
          nextPlan = nextPlan.replaceOutputPath(
            oldPath: outputPath,
            newPath: safePath,
          );
        }

        final workingPath = _workingPathFor(
          taskId: task.id,
          finalPath: safePath,
          stepIndex: stepIndex,
        );
        final workingFile = File(workingPath);
        await workingFile.create(recursive: true);
        await _setWindowsHidden(workingPath, hidden: true);
        preparedSteps.add(
          FfmpegCommandStep(
            args: const [],
            label: step.label,
            outputPath: safePath,
            workingOutputPath: workingPath,
          ),
        );
        nextPlan = nextPlan.replaceExecutionOutputPath(
          finalPath: safePath,
          workingPath: workingPath,
        );
      }
    } on Object {
      for (final step in preparedSteps) {
        await discardStep(step);
      }
      rethrow;
    }

    return OutputPreflightResult(plan: nextPlan, policyTags: tags);
  }

  @override
  Future<String?> publish(FfmpegCommandStep step) async {
    final finalPath = step.outputPath;
    final workingPath = step.workingOutputPath;
    if (finalPath == null || workingPath == null) {
      return finalPath;
    }

    final normalizedReserved = outputPathBuilder.normalizeForComparison(
      finalPath,
    );
    var publishPath = finalPath;
    if (await File(publishPath).exists()) {
      publishPath = _uniqueSafePath(
        preferredPath: publishPath,
        inputPath: '',
        reservedPaths: _reservedFinalPaths.difference({normalizedReserved}),
      );
    }

    try {
      await File(workingPath).rename(publishPath);
      await _setWindowsHidden(publishPath, hidden: false);
      return publishPath;
    } finally {
      _reservedFinalPaths.remove(normalizedReserved);
    }
  }

  @override
  Future<void> discardStep(FfmpegCommandStep step) async {
    final workingPath = step.workingOutputPath;
    try {
      if (workingPath != null) {
        final file = File(workingPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } on Object {
      // Best-effort cleanup; the task failure remains authoritative.
    } finally {
      final finalPath = step.outputPath;
      if (finalPath != null) {
        _reservedFinalPaths.remove(
          outputPathBuilder.normalizeForComparison(finalPath),
        );
      }
    }
  }

  @override
  Future<void> discardPlan(FfmpegCommandPlan plan) async {
    for (final step in plan.steps) {
      await discardStep(step);
    }
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

  String _workingPathFor({
    required String taskId,
    required String finalPath,
    required int stepIndex,
  }) {
    final directory = path.dirname(finalPath);
    final extension = path.extension(finalPath);
    final baseName = path.basenameWithoutExtension(finalPath);
    final safeTaskId = taskId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final token = DateTime.now().microsecondsSinceEpoch;
    return path.join(
      directory,
      '.framelean-$safeTaskId-$token-$stepIndex-$baseName.partial$extension',
    );
  }

  Future<void> _setWindowsHidden(
    String filePath, {
    required bool hidden,
  }) async {
    if (!Platform.isWindows) {
      return;
    }
    final result = await Process.run('attrib.exe', [
      hidden ? '+H' : '-H',
      filePath,
    ]);
    if (result.exitCode != 0 && hidden) {
      throw StateError('无法隐藏运行中的临时输出文件: $filePath');
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
