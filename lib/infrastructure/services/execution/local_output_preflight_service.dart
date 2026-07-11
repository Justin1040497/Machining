import 'dart:io';
import 'dart:math' as math;

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
        // 不预先创建工作文件，让 FFmpeg 自己创建输出文件。
        // 预先创建空文件可能导致 FFmpeg 因文件已存在而行为异常，
        // 且在 Windows 上创建文件可能触发 attrib.exe 隐藏操作，
        // 该操作失败不应阻断整个任务。
        // 隐藏属性设置改为非致命的最佳努力操作。
        await _setWindowsHiddenBestEffort(workingPath, hidden: true);
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
      await _renameWithRetry(workingPath, publishPath);
      await _setWindowsHiddenBestEffort(publishPath, hidden: false);
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

  /// 预检输出目录是否可写入。
  ///
  /// 测试创建探针文件、写入内容、重命名和删除，
  /// 确保目录支持 FFmpeg 输出所需的全部文件操作。
  /// 探针文件名使用随机数确保并发安全。
  /// 无论成功还是失败，都尽力清理探针文件。
  Future<void> _assertWritable(Directory directory) async {
    final token = math.Random.secure().nextInt(0x7fffffff);
    final probePath = path.join(
      directory.path,
      '.framelean-write-test-$token.tmp',
    );
    final renamePath = path.join(
      directory.path,
      '.framelean-write-test-$token-renamed.tmp',
    );
    final probe = File(probePath);

    try {
      // 测试创建并写入探针文件
      await probe.writeAsString('ok');

      // 测试重命名探针文件
      await probe.rename(renamePath);

      // 测试删除重命名后的探针文件
      final renamedFile = File(renamePath);
      if (await renamedFile.exists()) {
        await renamedFile.delete();
      }
    } on Object catch (error) {
      // 尽力清理残留探针文件
      try {
        if (await probe.exists()) {
          await probe.delete();
        }
      } on Object {
        // 清理失败不影响错误报告
      }
      try {
        final renamedFile = File(renamePath);
        if (await renamedFile.exists()) {
          await renamedFile.delete();
        }
      } on Object {
        // 清理失败不影响错误报告
      }
      throw StateError('输出目录不可写: ${directory.path} ($error)');
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

  /// 在 Windows 上设置或取消文件隐藏属性（最佳努力）。
  ///
  /// 该操作失败不会阻断媒体处理任务。隐藏属性只是用户体验功能，
  /// 杀毒软件、系统策略或文件系统差异都可能导致 attrib.exe 失败，
  /// 不应将此类失败解释为输出目录不可写。
  Future<void> _setWindowsHiddenBestEffort(
    String filePath, {
    required bool hidden,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      final result = await Process.run(
        'attrib.exe',
        <String>[
          hidden ? '+H' : '-H',
          filePath,
        ],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        // 记录警告但不抛出异常。隐藏属性不是任务成功的必要条件。
        stderr.writeln(
          'FrameLean: attrib.exe 返回非零退出码 ${result.exitCode}，'
          'filePath=$filePath, hidden=$hidden, '
          'stderr=${result.stderr.toString().trim()}',
        );
      }
    } on Object catch (error) {
      // 记录警告但不抛出异常。attrib.exe 启动失败不应中断任务。
      stderr.writeln(
        'FrameLean: attrib.exe 执行失败（非致命），'
        'filePath=$filePath, hidden=$hidden, error=$error',
      );
    }
  }

  /// 在 Windows 上重命名文件，对短暂文件占用进行有限重试。
  ///
  /// Windows 上杀毒软件扫描、缩略图程序或资源管理器预览
  /// 可能短暂占用文件，导致 rename 返回 sharing violation。
  /// 使用递增等待重试策略处理此类短暂冲突。
  ///
  /// 非 Windows 平台直接重命名，不重试。
  Future<void> _renameWithRetry(
    String sourcePath,
    String targetPath,
  ) async {
    if (!Platform.isWindows) {
      await File(sourcePath).rename(targetPath);
      return;
    }

    const retryDelays = [
      Duration(milliseconds: 100),
      Duration(milliseconds: 250),
    ];

    for (var attempt = 0; attempt <= retryDelays.length; attempt += 1) {
      try {
        await File(sourcePath).rename(targetPath);
        return;
      } on FileSystemException catch (error) {
        final isSharingViolation = error.osError?.errorCode == 32;
        final isAccessDenied = error.osError?.errorCode == 5;
        final isLastAttempt = attempt == retryDelays.length;

        if (isLastAttempt || (!isSharingViolation && !isAccessDenied)) {
          rethrow;
        }

        await Future<void>.delayed(retryDelays[attempt]);
      }
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
