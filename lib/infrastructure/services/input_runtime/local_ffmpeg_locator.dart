import 'dart:async';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:path/path.dart' as path;

/// 使用本地文件系统和系统 PATH 解析 FFmpeg / FFprobe
class LocalFfmpegLocator implements FfmpegLocator {
  final Duration validateTimeout;

  LocalFfmpegLocator({this.validateTimeout = ffprobeValidationTimeout});

  @override
  Future<ResolvedFfmpegRuntime> resolve({
    String? customFfmpegPath,
    String? customFfprobePath,
  }) async {
    final ffmpeg = await resolveTool(
      toolName: 'ffmpeg',
      customPath: customFfmpegPath,
    );
    final ffprobe = await resolveTool(
      toolName: 'ffprobe',
      customPath: customFfprobePath,
    );

    return ResolvedFfmpegRuntime(
      ffmpeg: ffmpeg,
      ffprobe: ffprobe,
      encoderCapabilities: ffmpeg == null
          ? FfmpegEncoderCapabilities.softwareOnly
          : await detectEncoderCapabilities(ffmpeg.path),
    );
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfmpegPath(String inputPath) {
    return validateCustomPath(toolName: 'ffmpeg', inputPath: inputPath);
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfprobePath(String inputPath) {
    return validateCustomPath(toolName: 'ffprobe', inputPath: inputPath);
  }

  /// 启动解析时使用：custom 不可用就继续尝试 bundled 和 systemPath
  Future<ResolvedFfmpegTool?> resolveTool({
    required String toolName,
    required String? customPath,
  }) async {
    final customTool = await resolveCustomTool(
      toolName: toolName,
      customPath: customPath,
    );
    if (customTool != null) {
      return customTool;
    }

    final bundledTool = await resolveBundledTool(toolName);
    if (bundledTool != null) {
      return bundledTool;
    }

    final knownSystemTool = await resolveKnownSystemTool(toolName);
    if (knownSystemTool != null) {
      return knownSystemTool;
    }

    return resolveSystemPathTool(toolName);
  }

  /// 用户主动设置路径时使用：路径不可用必须抛出异常，让 UI 有机会提示
  Future<ResolvedFfmpegTool> validateCustomPath({
    required String toolName,
    required String inputPath,
  }) async {
    if (await canExecuteTool(inputPath)) {
      return ResolvedFfmpegTool(
        path: inputPath,
        source: FfmpegBinarySource.custom,
      );
    }

    throw InvalidFfmpegToolPathException(
      toolName: toolName,
      inputPath: inputPath,
    );
  }

  /// 检查用户保存过的 custom 路径；启动阶段不可用时不抛错，继续降级
  Future<ResolvedFfmpegTool?> resolveCustomTool({
    required String toolName,
    required String? customPath,
  }) async {
    if (customPath == null || customPath.trim().isEmpty) {
      return null;
    }

    if (await canExecuteTool(customPath)) {
      return ResolvedFfmpegTool(
        path: customPath,
        source: FfmpegBinarySource.custom,
      );
    }

    return null;
  }

  /// 检查应用内置工具路径，后续打包 ffmpeg / ffprobe 时只需要放到这些目录
  Future<ResolvedFfmpegTool?> resolveBundledTool(String toolName) async {
    for (final candidate in bundledCandidates(toolName)) {
      if (await canExecuteTool(candidate)) {
        return ResolvedFfmpegTool(
          path: candidate,
          source: FfmpegBinarySource.bundled,
        );
      }
    }

    return null;
  }

  /// 检查系统 PATH 中是否存在工具
  Future<ResolvedFfmpegTool?> resolveSystemPathTool(String toolName) async {
    final result = await runCommand(Platform.isWindows ? 'where' : 'which', [
      toolName,
    ]);

    if (result == null || result.exitCode != 0) {
      return null;
    }

    final output = result.stdout.toString().trim();
    if (output.isEmpty) {
      return null;
    }

    final firstPath = output.split(RegExp(r'\r?\n')).first.trim();
    if (firstPath.isEmpty || !await canExecuteTool(firstPath)) {
      return null;
    }

    return ResolvedFfmpegTool(
      path: firstPath,
      source: FfmpegBinarySource.systemPath,
    );
  }

  /// macOS 图形应用不一定继承 shell PATH，补充 Homebrew 常见安装目录。
  Future<ResolvedFfmpegTool?> resolveKnownSystemTool(String toolName) async {
    for (final candidate in knownSystemCandidates(toolName)) {
      if (await canExecuteTool(candidate)) {
        return ResolvedFfmpegTool(
          path: candidate,
          source: FfmpegBinarySource.systemPath,
        );
      }
    }

    return null;
  }

  /// 用 `工具路径 -version` 判断这个路径是否真的是可执行工具
  Future<bool> canExecuteTool(String toolPath) async {
    final file = File(toolPath);
    if (!await file.exists()) {
      return false;
    }

    final result = await runCommand(toolPath, ['-version']);
    return result != null && result.exitCode == 0;
  }

  /// 统一运行外部命令，超时或启动失败都视为不可用
  Future<ProcessResult?> runCommand(
    String executable,
    List<String> args,
  ) async {
    try {
      return await Process.run(
        executable,
        args,
        runInShell: Platform.isWindows,
      ).timeout(validateTimeout);
    } on Object {
      return null;
    }
  }

  Future<FfmpegEncoderCapabilities> detectEncoderCapabilities(
    String ffmpegPath,
  ) async {
    final result = await runCommand(ffmpegPath, ['-hide_banner', '-encoders']);
    if (result == null || result.exitCode != 0) {
      return FfmpegEncoderCapabilities.assumeBundledFallback(
        autoBackendPriority: autoBackendPriority(),
      );
    }

    return FfmpegEncoderCapabilities.fromEncodersOutput(
      '${result.stdout}\n${result.stderr}',
      autoBackendPriority: autoBackendPriority(),
    );
  }

  List<EncoderBackend> autoBackendPriority() {
    if (Platform.isMacOS) {
      return const [EncoderBackend.videotoolbox];
    }

    if (Platform.isWindows) {
      return const [
        EncoderBackend.nvenc,
        EncoderBackend.qsv,
        EncoderBackend.amf,
      ];
    }

    return const [];
  }

  /// 生成当前系统可能存在的内置工具候选路径
  List<String> bundledCandidates(String toolName) {
    final executableName = Platform.isWindows ? '$toolName.exe' : toolName;
    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final currentDirectory = Directory.current.path;

    return [
      path.join(executableDirectory, executableName),
      path.join(executableDirectory, 'ffmpeg', executableName),
      path.join(executableDirectory, '..', 'Resources', executableName),
      path.join(
        executableDirectory,
        '..',
        'Resources',
        'ffmpeg',
        executableName,
      ),
      path.join(currentDirectory, 'tools', 'ffmpeg', executableName),
      path.join(currentDirectory, 'bin', executableName),
    ];
  }

  List<String> knownSystemCandidates(String toolName) {
    final executableName = Platform.isWindows ? '$toolName.exe' : toolName;

    if (Platform.isMacOS) {
      return [
        path.join('/opt/homebrew/bin', executableName),
        path.join('/usr/local/bin', executableName),
        path.join('/usr/bin', executableName),
      ];
    }

    if (Platform.isLinux) {
      return [
        path.join('/usr/local/bin', executableName),
        path.join('/usr/bin', executableName),
        path.join('/bin', executableName),
      ];
    }

    return const [];
  }
}
