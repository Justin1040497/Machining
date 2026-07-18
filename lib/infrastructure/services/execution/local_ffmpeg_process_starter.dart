import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:path/path.dart' as path;

class LocalFfmpegProcessStarter implements FfmpegProcessStarter {
  @override
  Future<StartedFfmpegProcess> start({
    required String ffmpegPath,
    required List<String> args,
    required File logFile,
  }) async {
    // 确保 FFmpeg 路径为绝对路径，不依赖当前工作目录。
    // Windows 打包后工作目录可能不可预测，甚至可能是安装目录或系统目录。
    final resolvedFfmpegPath = path.isAbsolute(ffmpegPath)
        ? ffmpegPath
        : path.absolute(ffmpegPath);

    final sink = logFile.openWrite(mode: FileMode.append);
    sink.writeln('ffmpegPath: $resolvedFfmpegPath');
    sink.writeln('args: ${args.join(' ')}');
    sink.writeln('workingDirectory: ${Directory.current.path}');
    sink.writeln('platform: ${Platform.operatingSystem}');
    sink.writeln('');
    await sink.close();

    // 使用 Process.start 而非 shell 拼接，每个参数为独立字符串，
    // 避免路径中空格、中文、特殊字符被 shell 误解析。
    final process = await Process.start(resolvedFfmpegPath, args);
    return StartedFfmpegProcess(process: process, logFile: logFile);
  }
}
