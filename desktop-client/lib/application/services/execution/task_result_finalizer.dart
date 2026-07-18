import 'dart:io';

import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/execution/output_preflight_service.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/library.dart';

class CompletedTaskResult {
  const CompletedTaskResult({
    required this.task,
    required this.outputPath,
    required this.outputSize,
    required this.completedAt,
  });

  final MediaTask task;
  final String outputPath;
  final int? outputSize;
  final int completedAt;
}

class TaskResultFinalizationException implements Exception {
  const TaskResultFinalizationException({
    required this.stage,
    required this.code,
    required this.userMessage,
    required this.technicalSummary,
  });

  final TaskFailureStage stage;
  final TaskFailureCode code;
  final String userMessage;
  final String technicalSummary;

  @override
  String toString() => technicalSummary;
}

class TaskResultFinalizer {
  const TaskResultFinalizer({
    required this.repository,
    required this.outputPreflightService,
    required this.now,
  });

  final MediaTaskRepository repository;
  final OutputPreflightService outputPreflightService;
  final Future<DateTime> Function() now;

  Future<CompletedTaskResult> publishCompleted({
    required MediaTask task,
    required FfmpegCommandStep step,
  }) async {
    late final String? publishedPath;
    try {
      publishedPath = await outputPreflightService.publish(step);
    } on Object catch (error) {
      throw TaskResultFinalizationException(
        stage: TaskFailureStage.outputPublication,
        code: TaskFailureCode.outputPublishFailed,
        userMessage: '媒体处理已完成，但临时文件无法发布为最终文件。',
        technicalSummary: '输出文件发布失败: $error',
      );
    }
    late final bool publishedOutputUsable;
    try {
      publishedOutputUsable =
          publishedPath != null &&
          await outputPreflightService.isPublishedOutputUsable(publishedPath);
    } on Object catch (error) {
      throw TaskResultFinalizationException(
        stage: TaskFailureStage.outputValidation,
        code: TaskFailureCode.outputUnreadable,
        userMessage: '处理结果不存在、为空或无法读取。',
        technicalSummary: '最终输出文件校验失败: $error',
      );
    }
    if (!publishedOutputUsable) {
      throw const TaskResultFinalizationException(
        stage: TaskFailureStage.outputValidation,
        code: TaskFailureCode.outputUnreadable,
        userMessage: '处理结果不存在、为空或无法读取。',
        technicalSummary: '最终输出文件不存在、为空或不可读',
      );
    }
    int? outputSize;
    try {
      outputSize = await File(publishedPath).length();
    } on Object {
      // Test/no-op output services may not materialize files. The local
      // implementation verifies existence and readability before this point.
    }
    final completedAt = (await now()).millisecondsSinceEpoch;
    final completedTask = task
        .copyWith(outputPath: publishedPath)
        .markCompleted(completedAt: completedAt, outputFileSize: outputSize);
    return CompletedTaskResult(
      task: completedTask,
      outputPath: publishedPath,
      outputSize: outputSize,
      completedAt: completedAt,
    );
  }

  Future<void> persistCompleted(CompletedTaskResult result) {
    return repository.saveTask(result.task);
  }

  Future<MediaTask> markFailed(MediaTask task, TaskFailure failure) async {
    final failedTask = task
        .markFailed(failure)
        .copyWith(clearOutputPath: true, clearOutputFileSize: true);
    await repository.saveTask(failedTask);
    return failedTask;
  }
}
