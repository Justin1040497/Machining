import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/services/app_update/updater_helper_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalUpdaterHelperLauncher implements UpdaterHelperLauncher {
  const LocalUpdaterHelperLauncher();

  @override
  Future<void> launch(UpdaterHelperLaunchRequest request) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('当前版本只支持 Windows 自动安装更新');
    }

    final executableDirectory = p.dirname(Platform.resolvedExecutable);
    final helperPath = p.join(
      executableDirectory,
      'FrameLeanUpdaterHelper.exe',
    );
    if (!await File(helperPath).exists()) {
      throw StateError('找不到更新助手：$helperPath');
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final requestFile = File(
      p.join(
        supportDirectory.path,
        'updates',
        'updater-helper-request-${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await requestFile.create(recursive: true);
    await requestFile.writeAsString(
      jsonEncode({
        'installerPath': request.installerPath,
        'version': request.release.version,
        'buildNumber': request.release.buildNumber,
        'currentProcessId': request.currentProcessId,
        'appExecutablePath': Platform.resolvedExecutable,
      }),
    );

    await Process.start(helperPath, [
      requestFile.path,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
