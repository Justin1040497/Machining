import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAppUpdatePackageDownloader implements AppUpdatePackageDownloader {
  LocalAppUpdatePackageDownloader({HttpClient? httpClient})
    : httpClient = httpClient ?? HttpClient();

  final HttpClient httpClient;

  @override
  Future<AppUpdateDownloadResult> download({
    required AppUpdateDownloadTicket ticket,
    required String version,
    required String platform,
    required AppUpdateDownloadCancellationToken cancellationToken,
    required AppUpdateDownloadProgressCallback onProgress,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final updateDirectory = Directory(
      p.join(directory.path, 'updates', version, platform),
    );
    await updateDirectory.create(recursive: true);

    final file = File(p.join(updateDirectory.path, ticket.package.fileName));
    final existingBytes = await file.exists() ? await file.length() : 0;
    final totalBytes = ticket.package.sizeBytes;

    if (existingBytes >= totalBytes) {
      await _verifySha256(file, ticket.package.sha256);
      onProgress(totalBytes, totalBytes);
      return AppUpdateDownloadResult(filePath: file.path);
    }

    final request = await httpClient.getUrl(ticket.downloadUrl);
    if (existingBytes > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '更新包下载失败：${response.statusCode}',
        uri: ticket.downloadUrl,
      );
    }

    var downloadedBytes = existingBytes;
    final sink = file.openWrite(mode: FileMode.append);
    try {
      await for (final chunk in response) {
        if (cancellationToken.isCancelled) {
          throw const AppUpdateDownloadPausedException();
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        onProgress(downloadedBytes, totalBytes);
      }
    } finally {
      await sink.close();
    }

    if (downloadedBytes != totalBytes) {
      throw StateError('更新包大小不匹配：$downloadedBytes / $totalBytes');
    }
    await _verifySha256(file, ticket.package.sha256);
    onProgress(totalBytes, totalBytes);
    return AppUpdateDownloadResult(filePath: file.path);
  }

  Future<void> _verifySha256(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    final actual = digest.toString().toLowerCase();
    if (actual != expected.toLowerCase()) {
      throw StateError('更新包 SHA-256 校验失败');
    }
  }
}
