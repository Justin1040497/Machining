import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';

class LaunchCleanUninstallerUseCase {
  const LaunchCleanUninstallerUseCase({required this.uninstaller});

  final AppUninstaller uninstaller;

  Future<void> call({required int currentProcessId}) {
    return uninstaller.launchCleanUninstall(currentProcessId: currentProcessId);
  }
}
