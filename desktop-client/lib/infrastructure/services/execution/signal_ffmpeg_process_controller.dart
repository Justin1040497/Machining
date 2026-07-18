import 'dart:io';

import 'package:framelean/application/library.dart';

class SignalFfmpegProcessController implements FfmpegProcessController {
  const SignalFfmpegProcessController();

  @override
  Future<void> pause(StartedFfmpegProcess startedProcess) async {
    sendSignal(startedProcess, ProcessSignal.sigstop, '暂停');
  }

  @override
  Future<void> resume(StartedFfmpegProcess startedProcess) async {
    sendSignal(startedProcess, ProcessSignal.sigcont, '继续');
  }

  @override
  Future<void> terminate(StartedFfmpegProcess startedProcess) async {
    sendSignal(startedProcess, ProcessSignal.sigterm, '终止');
  }

  void sendSignal(
    StartedFfmpegProcess startedProcess,
    ProcessSignal signal,
    String action,
  ) {
    final succeeded = startedProcess.process.kill(signal);
    if (!succeeded) {
      throw StateError('FFmpeg 进程$action失败');
    }
  }
}
