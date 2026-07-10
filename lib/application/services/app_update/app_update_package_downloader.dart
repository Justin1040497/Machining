import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/domain/library.dart';

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

  /// Returns the file path of an existing valid package in the download
  /// directory, or `null` if no valid package exists.
  ///
  /// A package is valid when its SHA-256 digest matches [package.sha256] and,
  /// when the verifier is configured, its Ed25519 signature is verified.
  Future<String?> findExistingValidPackage({
    required AppUpdatePackageInfo package,
    required String version,
    required String platform,
  });
}
