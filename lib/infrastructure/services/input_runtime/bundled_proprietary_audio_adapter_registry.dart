import 'dart:async';
import 'dart:io';

import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:path/path.dart' as path;

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

class BundledProprietaryAudioAdapterRegistry
    implements ProprietaryAudioAdapterRegistry {
  final Duration validateTimeout;
  final ProcessRunner? processRunner;
  final List<String> Function(ProprietaryAudioFormat format)? candidateBuilder;

  const BundledProprietaryAudioAdapterRegistry({
    this.validateTimeout = const Duration(seconds: 3),
    this.processRunner,
    this.candidateBuilder,
  });

  @override
  Future<ProprietaryAudioAdapterRuntime> resolveRuntime(
    ProprietaryAudioFormat format,
  ) async {
    for (final candidate in [
      ...candidatesFor(format),
      ...await systemPathCandidatesFor(format),
    ]) {
      final version = await adapterVersion(candidate);
      if (version == null) {
        continue;
      }

      return ProprietaryAudioAdapterRuntime(
        format: format,
        adapterName: adapterExecutableBaseName(format),
        adapterVersion: version,
        executablePath: candidate,
      );
    }

    throw ProprietaryAudioAdapterUnavailableException(
      format: format,
      message: '内置${format.displayName}音频适配器不可用，请重新安装应用或使用普通音频文件',
    );
  }

  List<String> candidatesFor(ProprietaryAudioFormat format) {
    final customCandidates = candidateBuilder?.call(format);
    if (customCandidates != null) {
      return customCandidates;
    }

    final executableName = executableFileName(format);
    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final currentDirectory = Directory.current.path;
    final adapterId = format.adapterId;
    final platformDirectory = currentPlatformDirectory();

    return [
      path.join(
        executableDirectory,
        'audio_adapters',
        adapterId,
        executableName,
      ),
      path.join(
        executableDirectory,
        '..',
        'Resources',
        'audio_adapters',
        adapterId,
        executableName,
      ),
      path.join(
        currentDirectory,
        'third_party',
        'audio_adapters',
        adapterId,
        platformDirectory,
        executableName,
      ),
      path.join(
        currentDirectory,
        'tools',
        'audio_adapters',
        adapterId,
        executableName,
      ),
      ...knownSystemCandidates(format),
    ];
  }

  Future<String?> adapterVersion(String executablePath) async {
    final file = File(executablePath);
    if (!await file.exists()) {
      return null;
    }

    try {
      final result = await runProcess(executablePath, const [
        '--version',
      ]).timeout(validateTimeout);

      final output = '${result.stdout}\n${result.stderr}'.trim();
      if (result.exitCode == 0 && output.isNotEmpty) {
        return output.split(RegExp(r'\r?\n')).first;
      }

      return 'unknown';
    } on Object {
      return 'unknown';
    }
  }

  Future<List<String>> systemPathCandidatesFor(
    ProprietaryAudioFormat format,
  ) async {
    try {
      final result = await runProcess(Platform.isWindows ? 'where' : 'which', [
        executableFileName(format),
      ]).timeout(validateTimeout);
      if (result.exitCode != 0) {
        return const [];
      }

      return result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<ProcessResult> runProcess(String executable, List<String> args) {
    final runner = processRunner;
    if (runner != null) {
      return runner(executable, args);
    }

    return Process.run(executable, args, runInShell: Platform.isWindows);
  }

  String executableFileName(ProprietaryAudioFormat format) {
    final baseName = adapterExecutableBaseName(format);
    return Platform.isWindows ? '$baseName.exe' : baseName;
  }

  String adapterExecutableBaseName(ProprietaryAudioFormat format) {
    return switch (format.adapterId) {
      'ncm' => 'ncmdump',
      'qmc' => 'framelean-qmc-adapter',
      _ => 'framelean-${format.adapterId}-adapter',
    };
  }

  List<String> knownSystemCandidates(ProprietaryAudioFormat format) {
    if (format != ProprietaryAudioFormat.ncm) {
      return const [];
    }

    final executableName = executableFileName(format);
    if (Platform.isMacOS) {
      return [
        path.join('/opt/homebrew/bin', executableName),
        path.join('/usr/local/bin', executableName),
      ];
    }

    if (Platform.isLinux) {
      return [
        path.join('/usr/local/bin', executableName),
        path.join('/usr/bin', executableName),
      ];
    }

    return const [];
  }

  String currentPlatformDirectory() {
    if (Platform.isMacOS) {
      return 'macos-arm64';
    }

    if (Platform.isWindows) {
      return 'windows-x64';
    }

    if (Platform.isLinux) {
      return 'linux-x64';
    }

    return 'unknown';
  }
}
