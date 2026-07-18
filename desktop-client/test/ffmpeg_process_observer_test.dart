import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_observer.dart';

void main() {
  group('LocalFfmpegProcessObserver', () {
    test('parses out_time_ms and reports progress', () async {
      final observer = LocalFfmpegProcessObserver(
        outputPathExists: (_) => true,
      );
      final progressValues = <double>[];
      final logFile = await createTempLogFile();
      final process = FakeProcess(
        stdoutText: 'frame=1\nout_time_ms=5000000\nspeed=1.0x\n',
        stderrText: 'normal ffmpeg log\n',
      );

      final result = await observer.observe(
        startedProcess: StartedFfmpegProcess(
          process: process,
          logFile: logFile,
        ),
        task: videoTaskWithDuration(durationMs: 10000),
        outputPath: '/videos/output.mp4',
        onProgress: (progress) async {
          progressValues.add(progress);
        },
      );

      expect(result.status, FfmpegProcessObservationStatus.completed);
      expect(progressValues, [0.5]);
      expect(await logFile.readAsString(), contains('normal ffmpeg log'));
    });

    test('keeps task running when duration is missing', () async {
      final observer = LocalFfmpegProcessObserver(
        outputPathExists: (_) => true,
      );
      final progressValues = <double>[];
      final logFile = await createTempLogFile();
      final process = FakeProcess(stdoutText: 'out_time_ms=5000000\n');

      final result = await observer.observe(
        startedProcess: StartedFfmpegProcess(
          process: process,
          logFile: logFile,
        ),
        task: videoTaskWithDuration(),
        outputPath: '/videos/output.mp4',
        onProgress: (progress) async {
          progressValues.add(progress);
        },
      );

      expect(result.status, FfmpegProcessObservationStatus.completed);
      expect(progressValues, isEmpty);
    });

    test(
      'step progress reports a single midpoint without parsing duration',
      () async {
        final observer = LocalFfmpegProcessObserver(
          outputPathExists: (_) => true,
        );
        final progressValues = <double>[];
        final logFile = await createTempLogFile();
        final process = FakeProcess(
          stdoutText: 'out_time_ms=5000000\n',
          stderrText: 'image conversion log\n',
        );

        final result = await observer.observe(
          startedProcess: StartedFfmpegProcess(
            process: process,
            logFile: logFile,
          ),
          task: videoTaskWithDuration(),
          outputPath: '/images/output.webp',
          progressMode: ProgressMode.step,
          onProgress: (progress) async {
            progressValues.add(progress);
          },
        );

        expect(result.status, FfmpegProcessObservationStatus.completed);
        expect(progressValues, [0.5]);
        expect(await logFile.readAsString(), contains('image conversion log'));
      },
    );

    test('fails when exitCode is not zero', () async {
      final observer = LocalFfmpegProcessObserver(
        outputPathExists: (_) => true,
      );
      final logFile = await createTempLogFile();
      final process = FakeProcess(exitCodeValue: 1);

      final result = await observer.observe(
        startedProcess: StartedFfmpegProcess(
          process: process,
          logFile: logFile,
        ),
        task: videoTaskWithDuration(durationMs: 10000),
        outputPath: '/videos/output.mp4',
        onProgress: (_) async {},
      );

      expect(result.status, FfmpegProcessObservationStatus.failed);
      expect(result.message, 'FFmpeg 退出码: 1');
    });

    test('includes stderr tail when exitCode is not zero', () async {
      final observer = LocalFfmpegProcessObserver(
        outputPathExists: (_) => true,
      );
      final logFile = await createTempLogFile();
      final process = FakeProcess(
        exitCodeValue: 1,
        stderrText: [
          'line 1',
          'line 2',
          'line 3',
          'line 4',
          'line 5',
          'line 6',
          'line 7',
          'line 8',
          'line 9',
          'Conversion failed!',
        ].join('\n'),
      );

      final result = await observer.observe(
        startedProcess: StartedFfmpegProcess(
          process: process,
          logFile: logFile,
        ),
        task: videoTaskWithDuration(durationMs: 10000),
        outputPath: '/videos/output.mp4',
        onProgress: (_) async {},
      );

      expect(result.status, FfmpegProcessObservationStatus.failed);
      expect(result.message, isNot(contains('line 1')));
      expect(result.message, contains('line 3'));
      expect(result.message, contains('Conversion failed!'));
      expect(await logFile.readAsString(), contains('line 1'));
    });

    test('fails when output file is missing', () async {
      final observer = LocalFfmpegProcessObserver(
        outputPathExists: (_) => false,
      );
      final logFile = await createTempLogFile();
      final process = FakeProcess();

      final result = await observer.observe(
        startedProcess: StartedFfmpegProcess(
          process: process,
          logFile: logFile,
        ),
        task: videoTaskWithDuration(durationMs: 10000),
        outputPath: '/videos/output.mp4',
        onProgress: (_) async {},
      );

      expect(result.status, FfmpegProcessObservationStatus.failed);
      expect(result.message, '输出文件缺失');
    });

    test(
      'kills stalled process and reports failure when no output exceeds stallTimeout',
      () async {
        // 模拟 ffmpeg 挂死：stdout/stderr 不产生任何数据，exitCode 永不完成，
        // 直到 kill 被调用。验证 stall 检测能主动终止进程并标记任务失败，
        // 而不是让任务永久卡 running 阻塞队列。
        final observer = LocalFfmpegProcessObserver(
          outputPathExists: (_) => true,
          stallTimeout: const Duration(milliseconds: 120),
          stallCheckInterval: const Duration(milliseconds: 40),
        );
        final logFile = await createTempLogFile();
        final process = StallingProcess();

        final result = await observer.observe(
          startedProcess: StartedFfmpegProcess(
            process: process,
            logFile: logFile,
          ),
          task: videoTaskWithDuration(durationMs: 10000),
          outputPath: '/videos/output.mp4',
          onProgress: (_) async {},
        );

        expect(result.status, FfmpegProcessObservationStatus.failed);
        expect(result.message, contains('无响应超时'));
        expect(process.killed, isTrue);
      },
    );
  });
}

Future<File> createTempLogFile() async {
  return File(
    '${Directory.systemTemp.path}/framelean-observer-test-${DateTime.now().microsecondsSinceEpoch}.log',
  ).create();
}

MediaTask videoTaskWithDuration({int? durationMs}) {
  return MediaTask.draft(
    inputPath: '/videos/input.mp4',
    fileName: 'input.mp4',
    mediaKind: MediaKind.video,
    sortOrder: 0,
  ).withAnalysisResult(MediaAnalysisResult(durationMs: durationMs));
}

class FakeProcess implements Process {
  final String stdoutText;
  final String stderrText;
  final int exitCodeValue;

  FakeProcess({
    this.stdoutText = '',
    this.stderrText = '',
    this.exitCodeValue = 0,
  });

  @override
  Future<int> get exitCode async => exitCodeValue;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(stdoutText));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(stderrText));

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return true;
  }
}

/// 模拟挂死的 ffmpeg 进程：流不产生数据，exitCode 永不完成，
/// 直到 kill() 被调用才会完成 exitCode 并关闭流。
class StallingProcess implements Process {
  final _exitCompleter = Completer<int>();
  final _stdoutController = StreamController<List<int>>();
  final _stderrController = StreamController<List<int>>();
  bool killed = false;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  int get pid => 2;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (killed) {
      return false;
    }
    killed = true;
    // 模拟 kill 后进程退出，让 exitCode Future 完成以解除主流程阻塞。
    _exitCompleter.complete(137);
    _stdoutController.close();
    _stderrController.close();
    return true;
  }
}
