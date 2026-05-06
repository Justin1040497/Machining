import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/ffmpeg_process_observer.dart';
import 'package:machining/application/services/ffmpeg_process_starter.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/infrastructure/services/local_ffmpeg_process_observer.dart';

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
  });
}

Future<File> createTempLogFile() async {
  return File(
    '${Directory.systemTemp.path}/machining-observer-test-${DateTime.now().microsecondsSinceEpoch}.log',
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
