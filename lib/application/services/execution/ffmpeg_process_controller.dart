import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';

abstract class FfmpegProcessController {
  Future<void> pause(StartedFfmpegProcess startedProcess);

  Future<void> resume(StartedFfmpegProcess startedProcess);

  Future<void> terminate(StartedFfmpegProcess startedProcess);
}
