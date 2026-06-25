import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class LocalFfmpegProcessObserver implements FfmpegProcessObserver {
  static const int stderrTailLineLimit = 8;

  /// 进程静默超过该时长即视为挂死，强制终止。
  /// ffmpeg 正常编码时（含 slow preset / 4K）progress 输出间隔通常 < 1 秒，
  /// 60 秒完全静默基本可判定为死锁（网络盘 IO 挂起、硬件编码器死锁等）。
  static const Duration defaultStallTimeout = Duration(seconds: 60);

  /// stall 检测的轮询间隔。
  static const Duration defaultStallCheckInterval = Duration(seconds: 5);

  final bool Function(String outputPath) outputPathExists;
  final Duration stallTimeout;
  final Duration stallCheckInterval;

  LocalFfmpegProcessObserver({
    bool Function(String outputPath)? outputPathExists,
    this.stallTimeout = defaultStallTimeout,
    this.stallCheckInterval = defaultStallCheckInterval,
  }) : outputPathExists =
           outputPathExists ?? ((outputPath) => File(outputPath).existsSync());

  @override
  Future<FfmpegProcessObservation> observe({
    required StartedFfmpegProcess startedProcess,
    required MediaTask task,
    required String? outputPath,
    ProgressMode progressMode = ProgressMode.timed,
    required Future<void> Function(double progress) onProgress,
  }) async {
    final stderrSink = startedProcess.logFile.openWrite(mode: FileMode.append);
    final stderrTail = <String>[];
    Object? streamError;
    var stalled = false;
    // 最后一次在 stdout/stderr 观察到数据的时间。ffmpeg 正常运行时会持续
    // 输出 progress，若长时间无任何输出则判定为挂死。
    var lastActivity = DateTime.now();

    void touchActivity() {
      lastActivity = DateTime.now();
    }

    if (progressMode == ProgressMode.step) {
      await onProgress(0.5);
    }

    final stdoutDone = progressMode == ProgressMode.timed
        ? observeStdout(
            startedProcess.process.stdout,
            task,
            onProgress,
            onActivity: touchActivity,
            onError: (error) => streamError ??= error,
          )
        : drainStdout(
            startedProcess.process.stdout,
            onActivity: touchActivity,
            onError: (error) => streamError ??= error,
          );
    final stderrDone = observeStderr(
      startedProcess.process.stderr,
      stderrSink,
      onLine: (line) {
        touchActivity();
        recordStderrTail(stderrTail, line);
      },
      onError: (error) => streamError ??= error,
    );

    // stall 检测定时器：周期性检查最后活动时间，超过阈值则强制 kill 进程，
    // 让 exitCode Future 完成，主流程得以继续并标记任务失败。
    // 原实现只监听 exitCode，进程挂死时任务会永久卡 running，占用执行位
    // 阻塞整个队列。
    final stallTimer = Timer.periodic(stallCheckInterval, (_) {
      if (stalled) {
        return;
      }
      if (DateTime.now().difference(lastActivity) >= stallTimeout) {
        stalled = true;
        try {
          startedProcess.process.kill(ProcessSignal.sigkill);
        } on Object {
          // kill 失败也无法做更多，主流程仍会等待 exitCode。
        }
      }
    });

    try {
      final exitCode = await startedProcess.process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      await stderrSink.close();

      if (stalled) {
        return FfmpegProcessObservation.failed(
          'FFmpeg 进程无响应超时（${stallTimeout.inSeconds} 秒无输出），已强制终止',
        );
      }

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
    } finally {
      stallTimer.cancel();
    }
  }

  Future<void> drainStdout(
    Stream<List<int>> stdout, {
    required void Function() onActivity,
    required void Function(Object error) onError,
  }) async {
    try {
      await for (final _ in stdout) {
        onActivity();
      }
    } on Object catch (error) {
      onError(error);
    }
  }

  Future<void> observeStdout(
    Stream<List<int>> stdout,
    MediaTask task,
    Future<void> Function(double progress) onProgress, {
    required void Function() onActivity,
    required void Function(Object error) onError,
  }) async {
    try {
      await for (final line
          in stdout.transform(utf8.decoder).transform(const LineSplitter())) {
        onActivity();
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
