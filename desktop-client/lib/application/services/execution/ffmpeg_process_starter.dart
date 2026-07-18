import 'dart:io';

class StartedFfmpegProcess {
  final Process process;
  final File logFile;

  const StartedFfmpegProcess({required this.process, required this.logFile});
}

abstract class FfmpegProcessStarter {
  Future<StartedFfmpegProcess> start({
    required String ffmpegPath,
    required List<String> args,
    required File logFile,
  });
}
