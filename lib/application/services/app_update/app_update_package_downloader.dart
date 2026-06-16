import 'package:framelean/application/services/app_update/app_update_client.dart';

typedef AppUpdateDownloadProgressCallback =
    void Function(int downloadedBytes, int totalBytes);

class AppUpdateDownloadCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({required this.filePath});

  final String filePath;
}

class AppUpdateDownloadPausedException implements Exception {
  const AppUpdateDownloadPausedException();

  @override
  String toString() => '下载已暂停';
}

abstract class AppUpdatePackageDownloader {
  Future<AppUpdateDownloadResult> download({
    required AppUpdateDownloadTicket ticket,
    required String version,
    required String platform,
    required AppUpdateDownloadCancellationToken cancellationToken,
    required AppUpdateDownloadProgressCallback onProgress,
  });
}
