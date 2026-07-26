import 'dart:io';

import 'package:path/path.dart' as path;

final class FEngineExecutableNotFoundException implements Exception {
  const FEngineExecutableNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class LocalFEngineExecutableLocator {
  LocalFEngineExecutableLocator({
    String? operatingSystem,
    String? resolvedExecutable,
    String? currentDirectory,
    Map<String, String>? environment,
    Future<bool> Function(String path)? fileExists,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       _currentDirectory = currentDirectory ?? Directory.current.path,
       _environment = environment ?? Platform.environment,
       _fileExists = fileExists ?? ((value) => File(value).exists());

  final String _operatingSystem;
  final String _resolvedExecutable;
  final String _currentDirectory;
  final Map<String, String> _environment;
  final Future<bool> Function(String path) _fileExists;

  Future<String> resolve() async {
    final override = _environment['FRAMELEAN_ENGINE_PATH']?.trim();
    if (override != null && override.isNotEmpty) {
      final resolved = path.normalize(path.absolute(override));
      if (await _fileExists(resolved)) {
        return resolved;
      }
      throw FEngineExecutableNotFoundException(
        'FRAMELEAN_ENGINE_PATH does not point to an existing file: $resolved',
      );
    }

    for (final candidate in _candidates()) {
      final resolved = path.normalize(path.absolute(candidate));
      if (await _fileExists(resolved)) {
        return resolved;
      }
    }
    throw const FEngineExecutableNotFoundException(
      'FrameLean Engine executable is not installed',
    );
  }

  Iterable<String> _candidates() sync* {
    final executableName = _operatingSystem == 'windows'
        ? 'framelean-engine.exe'
        : 'framelean-engine';
    final executableDirectory = path.dirname(_resolvedExecutable);

    yield path.join(executableDirectory, executableName);
    yield path.join(executableDirectory, 'fengine', executableName);
    if (_operatingSystem == 'macos') {
      yield path.join(executableDirectory, '..', 'Resources', executableName);
    }

    yield path.join(
      _currentDirectory,
      '..',
      'fengine',
      'target',
      'debug',
      executableName,
    );
    yield path.join(
      _currentDirectory,
      '..',
      'fengine',
      'target',
      'release',
      executableName,
    );
    yield path.join(
      _currentDirectory,
      'fengine',
      'target',
      'debug',
      executableName,
    );
    yield path.join(
      _currentDirectory,
      'fengine',
      'target',
      'release',
      executableName,
    );
  }
}
