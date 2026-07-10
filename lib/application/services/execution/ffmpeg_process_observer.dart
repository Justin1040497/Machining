import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/library.dart';

enum FfmpegProcessObservationStatus { completed, failed }

class FfmpegProcessObservation {
  final FfmpegProcessObservationStatus status;
  final String? message;

  const FfmpegProcessObservation._({required this.status, this.message});

  const FfmpegProcessObservation.completed()
    : this._(status: FfmpegProcessObservationStatus.completed);

  const FfmpegProcessObservation.failed(String message)
    : this._(status: FfmpegProcessObservationStatus.failed, message: message);
}

abstract class FfmpegProcessObserver {
  Future<FfmpegProcessObservation> observe({
    required StartedFfmpegProcess startedProcess,
    required MediaTask task,
    required String? outputPath,
    ProgressMode progressMode = ProgressMode.timed,
    required Future<void> Function(double progress) onProgress,
  });
}
