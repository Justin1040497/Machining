abstract interface class AppUninstaller {
  Future<AppUninstallAvailability> loadAvailability();

  Future<void> launchCleanUninstall({required int currentProcessId});
}

class AppUninstallAvailability {
  const AppUninstallAvailability({
    required this.supportedPlatform,
    required this.installedBuild,
    required this.requiresAdmin,
    this.cleanupScriptPath,
    this.installDir,
    this.unavailableReason,
  });

  final bool supportedPlatform;
  final bool installedBuild;
  final bool requiresAdmin;
  final String? cleanupScriptPath;
  final String? installDir;
  final String? unavailableReason;

  bool get available => supportedPlatform && installedBuild;

  static AppUninstallAvailability unavailable({
    required String reason,
    bool supportedPlatform = false,
    String? installDir,
    String? cleanupScriptPath,
  }) {
    return AppUninstallAvailability(
      supportedPlatform: supportedPlatform,
      installedBuild: false,
      requiresAdmin: false,
      cleanupScriptPath: cleanupScriptPath,
      installDir: installDir,
      unavailableReason: reason,
    );
  }
}
