import 'package:framelean/domain/value_objects/app_release_info.dart';

class UpdaterHelperLaunchRequest {
  const UpdaterHelperLaunchRequest({
    required this.release,
    required this.installerPath,
    required this.currentProcessId,
  });

  final AppReleaseInfo release;
  final String installerPath;
  final int currentProcessId;
}

abstract class UpdaterHelperLauncher {
  Future<void> launch(UpdaterHelperLaunchRequest request);
}
