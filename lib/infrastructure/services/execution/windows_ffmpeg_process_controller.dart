import 'package:flutter/services.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';

class WindowsFfmpegProcessController implements FfmpegProcessController {
  const WindowsFfmpegProcessController();

  static const MethodChannel _channel = MethodChannel(
    processControlChannel,
  );

  @override
  Future<void> pause(StartedFfmpegProcess startedProcess) {
    return invokeProcessControl('pause', startedProcess.process.pid, '暂停');
  }

  @override
  Future<void> resume(StartedFfmpegProcess startedProcess) {
    return invokeProcessControl('resume', startedProcess.process.pid, '继续');
  }

  @override
  Future<void> terminate(StartedFfmpegProcess startedProcess) {
    return invokeProcessControl('terminate', startedProcess.process.pid, '终止');
  }

  Future<void> invokeProcessControl(
    String method,
    int pid,
    String action,
  ) async {
    try {
      await _channel.invokeMethod<void>(method, {'pid': pid});
    } on PlatformException catch (error) {
      final detail = error.message?.trim();
      if (detail == null || detail.isEmpty) {
        throw StateError('Windows FFmpeg 进程$action失败: ${error.code}');
      }
      throw StateError('Windows FFmpeg 进程$action失败: $detail');
    } on MissingPluginException catch (_) {
      throw StateError('Windows FFmpeg 进程$action能力未注册');
    }
  }
}
