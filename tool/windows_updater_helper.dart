import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final startedAt = DateTime.now();
  final log = StringBuffer()
    ..writeln('FrameLean updater helper')
    ..writeln('startedAt=$startedAt');
  File? logFile;

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

    final requestFile = File(args.single);
    logFile = File('${requestFile.path}.log');
    final request = _UpdaterRequest.fromJson(
      jsonDecode(await requestFile.readAsString()) as Map<String, Object?>,
    );

    appendLog('version=${request.version} build=${request.buildNumber}');
    appendLog('installerPath=${request.installerPath}');
    appendLog('appExecutablePath=${request.appExecutablePath}');

    if (!await File(request.installerPath).exists()) {
      throw StateError('Installer does not exist: ${request.installerPath}');
    }

    await _waitForProcessExit(request.currentProcessId, appendLog);
    await _runInstaller(request, requestFile, appendLog);
    await _restartApp(request, appendLog);

    appendLog('completed');
    await flushLog();
    exitCode = 0;
  } on Object catch (error, stackTrace) {
    appendLog('failed: $error');
    appendLog(stackTrace.toString());
    stderr.writeln(error);
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
