import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';

class NoopAppUninstaller implements AppUninstaller {
  const NoopAppUninstaller({this.reason = '当前平台不支持应用内卸载'});

  final String reason;

  @override
  Future<AppUninstallAvailability> loadAvailability() async {
    return AppUninstallAvailability.unavailable(reason: reason);
  }

  @override
  Future<void> launchCleanUninstall({required int currentProcessId}) {
    throw StateError(reason);
  }
}
