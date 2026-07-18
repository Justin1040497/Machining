import 'package:framelean/domain/library.dart';

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
