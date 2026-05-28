import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/domain/entities/media_task.dart';

class LocalFfmpegProcessObserver implements FfmpegProcessObserver {
  static const int stderrTailLineLimit = 8;

  final bool Function(String outputPath) outputPathExists;

  LocalFfmpegProcessObserver({
    bool Function(String outputPath)? outputPathExists,
  }) : outputPathExists =
           outputPathExists ?? ((outputPath) => File(outputPath).existsSync());

  @override
  Future<FfmpegProcessObservation> observe({
    required StartedFfmpegProcess startedProcess,
    required MediaTask task,
    required String? outputPath,
    required Future<void> Function(double progress) onProgress,
  }) async {
    final stderrSink = startedProcess.logFile.openWrite(mode: FileMode.append);
    final stderrTail = <String>[];
    Object? streamError;

    final stdoutDone = observeStdout(
      startedProcess.process.stdout,
      task,
      onProgress,
      onError: (error) => streamError ??= error,
    );
    final stderrDone = observeStderr(
      startedProcess.process.stderr,
      stderrSink,
      onLine: (line) => recordStderrTail(stderrTail, line),
      onError: (error) => streamError ??= error,
    );

    final exitCode = await startedProcess.process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    await stderrSink.close();

    final error = streamError;
    if (error != null) {
      return FfmpegProcessObservation.failed('FFmpeg 输出监听失败: $error');
    }

    if (exitCode != 0) {
      return FfmpegProcessObservation.failed(
        buildExitFailureMessage(exitCode, stderrTail),
      );
    }

    if (outputPath != null && !outputPathExists(outputPath)) {
      return const FfmpegProcessObservation.failed('输出文件缺失');
    }

    return const FfmpegProcessObservation.completed();
  }

  Future<void> observeStdout(
    Stream<List<int>> stdout,
    MediaTask task,
    Future<void> Function(double progress) onProgress, {
    required void Function(Object error) onError,
  }) async {
    try {
      await for (final line
          in stdout.transform(utf8.decoder).transform(const LineSplitter())) {
        final outTimeUs = parseOutTimeMicroseconds(line);
        if (outTimeUs == null) {
          continue;
        }

        final progress = calculateProgress(outTimeUs, task);
        if (progress == null) {
          continue;
        }

        await onProgress(progress);
      }
    } on Object catch (error) {
      onError(error);
    }
  }

  Future<void> observeStderr(
    Stream<List<int>> stderr,
    IOSink stderrSink, {
    required void Function(String line) onLine,
    required void Function(Object error) onError,
  }) async {
    try {
      await for (final line
          in stderr.transform(utf8.decoder).transform(const LineSplitter())) {
        stderrSink.writeln(line);
        onLine(line);
      }
    } on Object catch (error) {
      onError(error);
    }
  }

  void recordStderrTail(List<String> stderrTail, String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      return;
    }

    stderrTail.add(trimmedLine);
    if (stderrTail.length > stderrTailLineLimit) {
      stderrTail.removeAt(0);
    }
  }

  String buildExitFailureMessage(int exitCode, List<String> stderrTail) {
    if (stderrTail.isEmpty) {
      return 'FFmpeg 退出码: $exitCode';
    }

    return 'FFmpeg 退出码: $exitCode\n${stderrTail.join('\n')}';
  }

  int? parseOutTimeMicroseconds(String line) {
    final trimmedLine = line.trim();
    if (!trimmedLine.startsWith('out_time_ms=')) {
      return null;
    }

    return int.tryParse(trimmedLine.substring('out_time_ms='.length));
  }

  double? calculateProgress(int outTimeUs, MediaTask task) {
    final durationMs = task.analysisResult?.durationMs;
    if (durationMs == null || durationMs <= 0) {
      return null;
    }

    final durationUs = durationMs * 1000;
    final progress = outTimeUs / durationUs;

    return progress.clamp(0, 0.999).toDouble();
  }
}
