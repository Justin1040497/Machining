import 'dart:io';

import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';
import 'package:path/path.dart' as p;

class WindowsCleanAppUninstaller implements AppUninstaller {
  WindowsCleanAppUninstaller({
    Directory? tempRoot,
    String? installDirOverride,
    String? cleanupScriptPathOverride,
    ProcessStarter? processStarter,
  }) : _tempRoot = tempRoot ?? Directory.systemTemp,
       _installDirOverride = installDirOverride,
       _cleanupScriptPathOverride = cleanupScriptPathOverride,
       _processStarter = processStarter ?? Process.start;

  final Directory _tempRoot;
  final String? _installDirOverride;
  final String? _cleanupScriptPathOverride;
  final ProcessStarter _processStarter;

  @override
  Future<AppUninstallAvailability> loadAvailability() async {
    if (!Platform.isWindows) {
      return AppUninstallAvailability.unavailable(reason: '仅 Windows 支持应用内卸载');
    }

    final installDir = _resolveInstallDir();
    final cleanupScriptPath = _resolveCleanupScriptPath(installDir);
    final installedBuild =
        cleanupScriptPath != null && await File(cleanupScriptPath).exists();

    if (!installedBuild) {
      return AppUninstallAvailability.unavailable(
        reason: '没有找到安装目录内的彻底卸载脚本',
        supportedPlatform: true,
        installDir: installDir,
        cleanupScriptPath: cleanupScriptPath,
      );
    }

    return AppUninstallAvailability(
      supportedPlatform: true,
      installedBuild: true,
      requiresAdmin: _looksLikeAdminInstallDir(installDir),
      cleanupScriptPath: cleanupScriptPath,
      installDir: installDir,
    );
  }

  @override
  Future<void> launchCleanUninstall({required int currentProcessId}) async {
    final availability = await loadAvailability();
    if (!availability.available) {
      throw StateError(availability.unavailableReason ?? '当前构建无法启动彻底卸载');
    }

    final installDir = availability.installDir!;
    final sourceScript = File(availability.cleanupScriptPath!);
    final tempScript = await _copyScriptToTemp(sourceScript);
    final scriptArgs = <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      tempScript.path,
      '-RemoveAll',
      '-Force',
      '-WaitForPid',
      currentProcessId.toString(),
      '-InstallDir',
      installDir,
      '-LaunchedFromApp',
    ];

    if (availability.requiresAdmin) {
      await _processStarter('PowerShell', <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        _buildElevatedStartCommand(scriptArgs),
      ], mode: ProcessStartMode.detached);
      return;
    }

    await _processStarter(
      'PowerShell',
      scriptArgs,
      mode: ProcessStartMode.detached,
    );
  }

  String _resolveInstallDir() {
    if (_installDirOverride != null && _installDirOverride.trim().isNotEmpty) {
      return _installDirOverride.trim();
    }

    return File(Platform.resolvedExecutable).parent.path;
  }

  String? _resolveCleanupScriptPath(String installDir) {
    if (_cleanupScriptPathOverride != null &&
        _cleanupScriptPathOverride.trim().isNotEmpty) {
      return _cleanupScriptPathOverride.trim();
    }

    final toolsScript = p.join(
      installDir,
      'tools',
      'FrameLean-Clean-Uninstall.ps1',
    );
    if (File(toolsScript).existsSync()) {
      return toolsScript;
    }

    return p.join(installDir, 'FrameLean-Clean-Uninstall.ps1');
  }

  Future<File> _copyScriptToTemp(File sourceScript) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final tempDir = Directory(
      p.join(_tempRoot.path, 'FrameLean', 'uninstall', timestamp),
    );
    await tempDir.create(recursive: true);

    final tempScript = File(
      p.join(tempDir.path, 'FrameLean-Clean-Uninstall.ps1'),
    );
    return sourceScript.copy(tempScript.path);
  }

  bool _looksLikeAdminInstallDir(String installDir) {
    final lower = p.normalize(installDir).toLowerCase();
    final programFiles = <String?>[
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
    ];

    return programFiles
        .whereType<String>()
        .map((path) => p.normalize(path).toLowerCase())
        .any((path) => lower == path || p.isWithin(path, lower));
  }

  String _buildElevatedStartCommand(List<String> scriptArgs) {
    final argumentList = scriptArgs.map(_powerShellSingleQuote).join(', ');
    return 'Start-Process -FilePath PowerShell -ArgumentList @($argumentList) -Verb RunAs';
  }

  String _powerShellSingleQuote(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }
}

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
    });
