import 'dart:io';

import 'package:framelean/application/library.dart';

class LocalFfmpegProcessStarter implements FfmpegProcessStarter {
  @override
  Future<StartedFfmpegProcess> start({
    required String ffmpegPath,
    required List<String> args,
    required File logFile,
  }) async {
    final sink = logFile.openWrite(mode: FileMode.append);
    sink.writeln('ffmpegPath: $ffmpegPath');
    sink.writeln('args: ${args.join(' ')}');
    sink.writeln('');
    await sink.close();

    final process = await Process.start(ffmpegPath, args);
    return StartedFfmpegProcess(process: process, logFile: logFile);
  }
}
