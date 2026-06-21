import 'dart:async';
import 'dart:io';

import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:path/path.dart' as path;
import 'package:framelean/app/constants.dart';

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

class BundledProprietaryAudioAdapterRegistry
    implements ProprietaryAudioAdapterRegistry {
  final Duration validateTimeout;
  final ProcessRunner? processRunner;
  final List<String> Function(ProprietaryAudioFormat format)? candidateBuilder;

  const BundledProprietaryAudioAdapterRegistry({
    this.validateTimeout = ffprobeValidationTimeout,
    this.processRunner,
    this.candidateBuilder,
  });

  @override
  Future<ProprietaryAudioAdapterRuntime> resolveRuntime(
    ProprietaryAudioFormat format,
  ) async {
    if (format == ProprietaryAudioFormat.ncm) {
      return const ProprietaryAudioAdapterRuntime(
        format: ProprietaryAudioFormat.ncm,
        adapterName: 'native-ncm-dart',
        adapterVersion: 'builtin',
        executablePath: '',
      );
    }

    for (final candidate in candidatesFor(format)) {
      final version = await adapterVersion(candidate);
      if (version == null) {
        continue;
      }

      return ProprietaryAudioAdapterRuntime(
        format: format,
        adapterName: adapterNameForExecutablePath(candidate),
        adapterVersion: version,
        executablePath: candidate,
      );
    }

    for (final candidate in await systemPathCandidatesFor(format)) {
      final version = await adapterVersion(candidate);
      if (version == null) {
        continue;
      }

      return ProprietaryAudioAdapterRuntime(
        format: format,
        adapterName: adapterNameForExecutablePath(candidate),
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

    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final currentDirectory = Directory.current.path;
    final adapterId = format.adapterId;
    final platformDirectory = currentPlatformDirectory();
    final candidates = <String>[];

    for (final executableName in executableFileNames(format)) {
      candidates.addAll([
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
      ]);
    }

    candidates.addAll(knownSystemCandidates(format));
    return candidates;
  }

  Future<String?> adapterVersion(String executablePath) async {
    final file = File(executablePath);
    if (!await file.exists()) {
      return null;
    }

    final adapterName = adapterNameForExecutablePath(executablePath);

    try {
      final result = await runProcess(
        executablePath,
        adapterProbeArguments(adapterName),
      ).timeout(validateTimeout);

      final output = '${result.stdout}\n${result.stderr}'.trim();
      if (adapterName == 'qmc-decrypt' && result.exitCode == 0) {
        return 'qmc-decrypt (version unavailable)';
      }

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
    final candidates = <String>[];
    for (final executableName in executableFileNames(format)) {
      try {
        final result = await runProcess(
          Platform.isWindows ? 'where' : 'which',
          [executableName],
        ).timeout(validateTimeout);
        if (result.exitCode != 0) {
          continue;
        }

        candidates.addAll(
          result.stdout
              .toString()
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        );
      } on Object {
        continue;
      }
    }

    return candidates;
  }

  Future<ProcessResult> runProcess(String executable, List<String> args) {
    final runner = processRunner;
    if (runner != null) {
      return runner(executable, args);
    }

    return Process.run(executable, args, runInShell: Platform.isWindows);
  }

  List<String> adapterProbeArguments(String adapterName) {
    if (adapterName == 'qmc-decrypt') {
      return const ['--help'];
    }

    return const ['--version'];
  }

  String executableFileName(ProprietaryAudioFormat format) {
    return executableFileNames(format).first;
  }

  List<String> executableFileNames(ProprietaryAudioFormat format) {
    return adapterExecutableBaseNames(format).map((baseName) {
      return Platform.isWindows ? '$baseName.exe' : baseName;
    }).toList();
  }

  String adapterExecutableBaseName(ProprietaryAudioFormat format) {
    return adapterExecutableBaseNames(format).first;
  }

  List<String> adapterExecutableBaseNames(ProprietaryAudioFormat format) {
    return switch (format.adapterId) {
      'qmc' => const ['framelean-qmc-adapter', 'qmc-decrypt'],
      _ => ['framelean-${format.adapterId}-adapter'],
    };
  }

  List<String> knownSystemCandidates(ProprietaryAudioFormat format) {
    return const [];
  }

  String adapterNameForExecutablePath(String executablePath) {
    final fileName = path.basename(executablePath);
    if (Platform.isWindows && fileName.toLowerCase().endsWith('.exe')) {
      return fileName.substring(0, fileName.length - 4);
    }

    return fileName;
  }

  String currentPlatformDirectory() {
    if (Platform.isMacOS) {
      return 'macos-universal';
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
