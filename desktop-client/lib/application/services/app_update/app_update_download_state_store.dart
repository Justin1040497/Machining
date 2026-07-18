import 'package:framelean/domain/library.dart';

class PersistedDownloadState {
  const PersistedDownloadState({
    required this.release,
    required this.filePath,
  });

  final AppReleaseInfo release;
  final String filePath;
}

abstract class AppUpdateDownloadStateStore {
  Future<PersistedDownloadState?> load();

  Future<void> save(PersistedDownloadState state);

  Future<void> clear();
}
