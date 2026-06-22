import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final startedAt = DateTime.now();
  final log = StringBuffer()
    ..writeln('FrameLean updater helper')
    ..writeln('startedAt=$startedAt');
  File? logFile;
  File? requestFile;
  _UpdaterRequest? request;

  void appendLog(String message) {
    log.writeln('${DateTime.now().toIso8601String()} $message');
  }

  Future<void> flushLog() async {
    final file = logFile;
    if (file == null) {
      return;
    }
    await file.writeAsString(log.toString(), flush: true);
  }

  try {
    if (!Platform.isWindows) {
      throw UnsupportedError('FrameLeanUpdaterHelper only supports Windows.');
    }
    if (args.length != 1) {
      throw const FormatException(
        'Usage: FrameLeanUpdaterHelper.exe <request-json-path>',
      );
    }

    requestFile = File(args.single);
    logFile = File('${requestFile.path}.log');
    request = _UpdaterRequest.fromJson(
      jsonDecode(await requestFile.readAsString()) as Map<String, Object?>,
    );

    appendLog('version=${request.version} build=${request.buildNumber}');
    appendLog('installerPath=${request.installerPath}');
    appendLog('appExecutablePath=${request.appExecutablePath}');

    if (!await File(request.installerPath).exists()) {
      throw StateError('Installer does not exist: ${request.installerPath}');
    }

    await _waitForProcessExit(request.currentProcessId, appendLog);
    await _gracePeriodAndCleanup(appendLog);
    await _runInstaller(request, requestFile, appendLog);

    try {
      await _verifyInstalledVersion(request, appendLog);
    } on Object catch (verifyError) {
      appendLog('first install verification failed: $verifyError');
      appendLog('retrying install after killing remaining processes');
      await _gracePeriodAndCleanup(appendLog);
      await _runInstaller(request, requestFile, appendLog);
      await _verifyInstalledVersion(request, appendLog);
    }

    await _restartApp(request, appendLog);
    await _clearSentinelFile(requestFile, appendLog);

    appendLog('completed');
    await flushLog();
    exitCode = 0;
  } on Object catch (error, stackTrace) {
    appendLog('failed: $error');
    appendLog(stackTrace.toString());
    stderr.writeln(error);
    if (request != null && requestFile != null) {
      await _writeSentinelFile(requestFile, request, error, appendLog);
      try {
        await _restartApp(request, appendLog);
        appendLog('restarted available app after update failure');
      } on Object catch (restartError) {
        appendLog('failed to restart available app: $restartError');
      }
    }
    await flushLog();
    exitCode = 1;
  }
}

Future<void> _waitForProcessExit(
  int processId,
  void Function(String message) log,
) async {
  if (processId <= 0) {
    return;
  }

  for (var attempt = 0; attempt < 90; attempt += 1) {
    if (!await _isProcessRunning(processId)) {
      log('main process exited');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  throw StateError('FrameLean did not exit within 90 seconds.');
}

Future<bool> _isProcessRunning(int processId) async {
  final result = await Process.run('tasklist.exe', [
    '/FI',
    'PID eq $processId',
    '/FO',
    'CSV',
    '/NH',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'tasklist.exe',
      const [],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }

  return '${result.stdout}'.contains('"$processId"');
}

Future<void> _verifyInstalledVersion(
  _UpdaterRequest request,
  void Function(String message) log,
) async {
  final registry = await _readRegistryValues(log);
  if (registry.version != request.version) {
    throw StateError(
      'Installed registry version mismatch: '
      '${registry.version} != ${request.version}',
    );
  }
  log('registry version verified: ${registry.version}');

  final expectedInstallPath = Directory(
    File(request.appExecutablePath).parent.path,
  ).absolute.path.toLowerCase();
  final installedPath = Directory(
    registry.installPath,
  ).absolute.path.toLowerCase();
  if (installedPath != expectedInstallPath) {
    throw StateError(
      'Installed path mismatch: $installedPath != $expectedInstallPath',
    );
  }
  log('registry install path verified: ${registry.installPath}');

  final executableVersion = await _readExecutableFileVersion(
    request.appExecutablePath,
    log,
  );
  final expectedExecutableVersion = '${request.version}.${request.buildNumber}';
  if (executableVersion != expectedExecutableVersion) {
    throw StateError(
      'Installed executable version mismatch: '
      '$executableVersion != $expectedExecutableVersion',
    );
  }
  log('executable FileVersionRaw verified: $executableVersion');
}

Future<_RegistryValues> _readRegistryValues(
  void Function(String message) log,
) async {
  for (final root in ['HKCU', 'HKLM']) {
    final result = await Process.run('reg.exe', [
      'query',
      '$root\\Software\\FrameLean\\FrameLean',
    ]);
    if (result.exitCode != 0) {
      log('$root registry query failed: ${result.stdout} ${result.stderr}');
      continue;
    }
    String? version;
    String? installPath;
    for (final line in '${result.stdout}'.split('\n')) {
      final match = RegExp(
        r'^\s*(Version|InstallPath)\s+REG_\S+\s+(.+?)\s*$',
      ).firstMatch(line);
      if (match?.group(1) == 'Version') {
        version = match?.group(2)?.trim();
      } else if (match?.group(1) == 'InstallPath') {
        installPath = match?.group(2)?.trim();
      }
    }
    if (version != null && installPath != null) {
      return _RegistryValues(version: version, installPath: installPath);
    }
  }
  throw StateError('Installed registry version or path was not found.');
}

Future<String> _readExecutableFileVersion(
  String appExecutablePath,
  void Function(String message) log,
) async {
  if (appExecutablePath.isEmpty || !await File(appExecutablePath).exists()) {
    throw StateError('Installed executable was not found: $appExecutablePath');
  }
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    r'$v=(Get-Item -LiteralPath $args[0]).VersionInfo.FileVersionRaw; "$($v.Major).$($v.Minor).$($v.Build).$($v.Revision)"',
    appExecutablePath,
  ]);
  if (result.exitCode != 0) {
    log('executable version query failed: ${result.stdout} ${result.stderr}');
    throw ProcessException(
      'powershell.exe',
      const [],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  final version = '${result.stdout}'.trim();
  if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(version)) {
    throw StateError(
      'Installed executable FileVersionRaw is invalid: $version',
    );
  }
  return version;
}

Future<void> _runInstaller(
  _UpdaterRequest request,
  File requestFile,
  void Function(String message) log,
) async {
  final installerLogPath = '${requestFile.path}.installer.log';
  log('starting installer log=$installerLogPath');
  final process = await Process.start(request.installerPath, [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/LOG=$installerLogPath',
  ]);

  process.stdout.transform(utf8.decoder).listen((line) {
    log('installer stdout: $line');
  });
  process.stderr.transform(utf8.decoder).listen((line) {
    log('installer stderr: $line');
  });

  final code = await process.exitCode;
  log('installer exitCode=$code');
  if (code != 0) {
    throw ProcessException(request.installerPath, const [], '', code);
  }

  await _validateInstallerLog(installerLogPath, log);
}

Future<void> _validateInstallerLog(
  String installerLogPath,
  void Function(String message) log,
) async {
  final logFile = File(installerLogPath);
  if (!await logFile.exists()) {
    log('installer log not found, cannot validate');
    return;
  }
  final content = await logFile.readAsString();
  final hasError = content.contains('Error on line ') ||
      content.contains('Internal error:') ||
      content.contains('Setup was interrupted');
  if (hasError) {
    // Extract error lines for diagnostics
    final errorLines = content
        .split('\n')
        .where((line) =>
            line.contains('Error on line ') ||
            line.contains('Internal error:') ||
            line.contains('Setup was interrupted'))
        .join('; ');
    throw StateError('Installer log contains errors: $errorLines');
  }
  log('installer log validated: no errors detected');
}

Future<void> _restartApp(
  _UpdaterRequest request,
  void Function(String message) log,
) async {
  if (request.appExecutablePath.isEmpty) {
    log('skip restart: empty appExecutablePath');
    return;
  }
  if (!await File(request.appExecutablePath).exists()) {
    log('skip restart: app executable missing');
    return;
  }

  await Process.start(
    request.appExecutablePath,
    const [],
    mode: ProcessStartMode.detached,
  );
  log('app restarted');
}

Future<void> _gracePeriodAndCleanup(
  void Function(String message) log,
) async {
  log('waiting grace period for file locks to release');
  await Future<void>.delayed(const Duration(seconds: 3));
  await _killFrameLeanProcesses(log);
}

Future<void> _killFrameLeanProcesses(
  void Function(String message) log,
) async {
  log('killing remaining FrameLean.exe processes');
  try {
    final result = await Process.run('taskkill.exe', [
      '/F',
      '/IM',
      'FrameLean.exe',
    ]);
    log('taskkill exitCode=${result.exitCode} stdout=${result.stdout}');
  } on Object catch (e) {
    log('taskkill failed (non-fatal): $e');
  }
}

Future<void> _writeSentinelFile(
  File requestFile,
  _UpdaterRequest request,
  Object error,
  void Function(String message) log,
) async {
  try {
    final updatesDir = requestFile.parent;
    final sentinel = File(
      '${updatesDir.path}${Platform.pathSeparator}update-failed.json',
    );
    await sentinel.writeAsString(
      '{"version":"${request.version}",'
      '"buildNumber":${request.buildNumber},'
      '"error":${jsonEncode(error.toString())},'
      '"timestamp":"${DateTime.now().toIso8601String()}"}',
    );
    log('sentinel file written: ${sentinel.path}');
  } on Object catch (e) {
    log('failed to write sentinel file: $e');
  }
}

Future<void> _clearSentinelFile(
  File requestFile,
  void Function(String message) log,
) async {
  try {
    final updatesDir = requestFile.parent;
    final sentinel = File(
      '${updatesDir.path}${Platform.pathSeparator}update-failed.json',
    );
    if (await sentinel.exists()) {
      await sentinel.delete();
      log('sentinel file cleared: ${sentinel.path}');
    }
  } on Object catch (e) {
    log('failed to clear sentinel file: $e');
  }
}

class _UpdaterRequest {
  const _UpdaterRequest({
    required this.installerPath,
    required this.version,
    required this.buildNumber,
    required this.currentProcessId,
    required this.appExecutablePath,
  });

  final String installerPath;
  final String version;
  final int buildNumber;
  final int currentProcessId;
  final String appExecutablePath;

  factory _UpdaterRequest.fromJson(Map<String, Object?> json) {
    return _UpdaterRequest(
      installerPath: _readString(json, 'installerPath'),
      version: _readString(json, 'version'),
      buildNumber: _readInt(json, 'buildNumber'),
      currentProcessId: _readInt(json, 'currentProcessId'),
      appExecutablePath: _readString(json, 'appExecutablePath'),
    );
  }
}

class _RegistryValues {
  const _RegistryValues({required this.version, required this.installPath});

  final String version;
  final String installPath;
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required string field: $key');
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Missing required int field: $key');
}
