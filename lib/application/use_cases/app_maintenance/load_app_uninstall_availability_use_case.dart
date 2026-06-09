import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';

class LoadAppUninstallAvailabilityUseCase {
  const LoadAppUninstallAvailabilityUseCase({required this.uninstaller});

  final AppUninstaller uninstaller;

  Future<AppUninstallAvailability> call() {
    return uninstaller.loadAvailability();
  }
}
