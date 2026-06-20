import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:framelean/application/services/app_update/enterprise_update_config_store.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/application/services/app_update/release_signature_verifier.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAppUpdatePackageDownloader implements AppUpdatePackageDownloader {
  LocalAppUpdatePackageDownloader({
    HttpClient? httpClient,
    Future<Directory> Function()? supportDirectoryProvider,
    this.configCache,
    this.signatureVerifier,
  }) : httpClient = httpClient ?? HttpClient(),
       supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final HttpClient httpClient;
  final Future<Directory> Function() supportDirectoryProvider;
  final EnterpriseUpdateConfigCache? configCache;
  final ReleaseSignatureVerifier? signatureVerifier;

  @override
  Future<AppUpdateDownloadResult> download({
    required AppUpdateDownloadTicket ticket,
    required String version,
    required String platform,
    required AppUpdateDownloadCancellationToken cancellationToken,
    required AppUpdateDownloadProgressCallback onProgress,
  }) async {
    final directory = await supportDirectoryProvider();
    final updateDirectory = Directory(
      p.join(directory.path, 'updates', version, platform),
    );
    await updateDirectory.create(recursive: true);

    if (p.basename(ticket.package.fileName) != ticket.package.fileName) {
      throw StateError('更新包文件名无效');
    }
    final file = File(p.join(updateDirectory.path, ticket.package.fileName));
    var existingBytes = await file.exists() ? await file.length() : 0;
    final totalBytes = ticket.package.sizeBytes;
    if (totalBytes <= 0) {
      throw StateError('更新包大小无效');
    }

    if (existingBytes > totalBytes) {
      await file.delete();
      existingBytes = 0;
    }

    if (existingBytes == totalBytes) {
      try {
        await _verifyPackage(file, ticket.package);
        onProgress(totalBytes, totalBytes);
        return AppUpdateDownloadResult(filePath: file.path);
      } on Object {
        await file.delete();
        existingBytes = 0;
      }
    }

    final request = await httpClient.getUrl(ticket.downloadUrl);
    if (existingBytes > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
    }
    final response = await request.close();
    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
        existingBytes > 0) {
      await file.delete();
      return download(
        ticket: ticket,
        version: version,
        platform: platform,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '更新包下载失败：${response.statusCode}',
        uri: ticket.downloadUrl,
      );
    }

    var append = false;
    if (existingBytes > 0 && response.statusCode == HttpStatus.partialContent) {
      if (!_hasValidContentRange(response, existingBytes, totalBytes)) {
        await file.delete();
        throw StateError('更新包断点响应无效');
      }
      append = true;
    } else if (existingBytes > 0) {
      await file.delete();
      existingBytes = 0;
    } else if (response.statusCode == HttpStatus.partialContent &&
        !_hasValidContentRange(response, 0, totalBytes)) {
      if (await file.exists()) {
        await file.delete();
      }
      throw StateError('更新包断点响应无效');
    }

    var downloadedBytes = existingBytes;
    final sink = file.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response) {
        if (cancellationToken.isCancelled) {
          throw const AppUpdateDownloadPausedException();
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (downloadedBytes > totalBytes) {
          throw StateError('更新包大小超过服务端元数据');
        }
        onProgress(downloadedBytes, totalBytes);
      }
    } on AppUpdateDownloadPausedException {
      rethrow;
    } on StateError {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      await sink.close();
    }

    if (downloadedBytes != totalBytes) {
      if (await file.exists()) {
        await file.delete();
      }
      throw StateError('更新包大小不匹配：$downloadedBytes / $totalBytes');
    }
    try {
      await _verifyPackage(file, ticket.package);
    } on Object {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
    onProgress(totalBytes, totalBytes);
    return AppUpdateDownloadResult(filePath: file.path);
  }

  bool _hasValidContentRange(
    HttpClientResponse response,
    int expectedStart,
    int expectedTotal,
  ) {
    final value = response.headers.value(HttpHeaders.contentRangeHeader);
    final match = value == null
        ? null
        : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(value.trim());
    if (match == null) {
      return false;
    }
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = int.tryParse(match.group(3)!);
    return start == expectedStart &&
        total == expectedTotal &&
        end != null &&
        end >= expectedStart &&
        end < expectedTotal;
  }

  Future<void> _verifyPackage(File file, AppUpdatePackageInfo package) async {
    await _verifySha256(file, package.sha256);
    await _verifySignature(file, package);
  }

  Future<void> _verifySha256(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    final actual = digest.toString().toLowerCase();
    if (actual != expected.toLowerCase()) {
      throw StateError('更新包 SHA-256 校验失败');
    }
  }

  Future<void> _verifySignature(File file, AppUpdatePackageInfo package) async {
    final verifier = signatureVerifier;
    final cache = configCache;
    if (verifier == null || cache == null) {
      return;
    }
    await verifier.verify(
      file: file,
      package: package,
      config: await cache.load(),
    );
  }
}
