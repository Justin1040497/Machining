import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:http/http.dart' as http;

class UpdateManifestUpdateChecker implements AppUpdateChecker {
  UpdateManifestUpdateChecker({
    required this.latestUpdateUri,
    http.Client? httpClient,
    Duration? requestTimeout,
  }) : _httpClient = httpClient ?? http.Client(),
       requestTimeout = requestTimeout ?? const Duration(seconds: 6);

  factory UpdateManifestUpdateChecker.frameLean({http.Client? httpClient}) {
    const endpoint = String.fromEnvironment(
      'FRAMELEAN_UPDATE_ENDPOINT',
      defaultValue: 'https://framelean-updates.example.com/v1/updates/latest',
    );

    return UpdateManifestUpdateChecker(
      latestUpdateUri: Uri.parse(endpoint),
      httpClient: httpClient,
    );
  }

  final http.Client _httpClient;
  final Uri latestUpdateUri;
  final Duration requestTimeout;

  @override
  Future<AppUpdateCheckResult> checkForUpdates({
    required AppVersion currentVersion,
    required AppUpdatePlatform platform,
  }) async {
    final release = await _fetchLatestRelease(platform: platform);

    return AppUpdateCheckResult(
      currentVersion: currentVersion,
      latestRelease: release,
    );
  }

  Future<AppUpdateRelease> _fetchLatestRelease({
    required AppUpdatePlatform platform,
  }) async {
    final requestUri = _withPlatformQuery(platform);
    try {
      final response = await _httpClient
          .get(
            requestUri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'FrameLean',
            },
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException('更新接口返回 HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return UpdateManifestParser.parseLatestUpdate(decoded);
    } on AppUpdateException {
      rethrow;
    } on FormatException {
      throw const AppUpdateException('更新接口响应格式无效');
    } on TimeoutException {
      throw const AppUpdateException('更新接口连接超时');
    } on HandshakeException {
      throw const AppUpdateException('更新接口 TLS 握手失败');
    } on SocketException catch (error) {
      throw AppUpdateException(_describeSocketError(error));
    } on Object {
      throw const AppUpdateException('更新接口网络连接失败');
    }
  }

  Uri _withPlatformQuery(AppUpdatePlatform platform) {
    return latestUpdateUri.replace(
      queryParameters: {
        ...latestUpdateUri.queryParameters,
        'platform': platform.updateApiValue,
      },
    );
  }

  static String _describeSocketError(SocketException error) {
    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('nodename nor servname') ||
        message.contains('name or service not known')) {
      return '更新接口 DNS 解析失败';
    }
    if (message.contains('connection refused')) {
      return '更新接口连接被拒绝';
    }
    if (message.contains('connection timed out')) {
      return '更新接口连接超时';
    }

    return '更新接口网络连接失败';
  }
}

abstract final class UpdateManifestParser {
  static AppUpdateRelease parseLatestUpdate(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      throw const AppUpdateException('更新接口响应格式无效');
    }

    final packageJson = _requiredObject(decoded, 'package');
    final checksumJson = _optionalObject(decoded['checksum']);

    return AppUpdateRelease(
      version: AppVersion.parse(_requiredString(decoded, 'version')),
      title: _requiredString(decoded, 'title'),
      releaseNotes: _stringOrFallback(decoded['releaseNotes'], ''),
      releasePageUrl: _requiredUri(decoded, 'releasePageUrl'),
      packageAsset: _parseAsset(packageJson),
      checksumAsset: checksumJson == null ? null : _parseAsset(checksumJson),
    );
  }

  static AppUpdateAsset _parseAsset(Map<String, Object?> json) {
    return AppUpdateAsset(
      name: _requiredString(json, 'name'),
      downloadUrl: _requiredUri(json, 'downloadUrl'),
      sizeBytes: _optionalInt(json['sizeBytes']),
      sha256: _optionalString(json['sha256']),
    );
  }

  static Map<String, Object?> _requiredObject(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map<String, Object?>) {
      return value;
    }

    throw AppUpdateException('更新接口响应缺少 $key');
  }

  static Map<String, Object?>? _optionalObject(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, Object?>) {
      return value;
    }

    throw const AppUpdateException('更新接口响应格式无效');
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw AppUpdateException('更新接口响应缺少 $key');
  }

  static Uri _requiredUri(Map<String, Object?> json, String key) {
    final value = _requiredString(json, key);
    final uri = Uri.parse(value);
    if (!uri.hasScheme) {
      throw AppUpdateException('更新接口响应中的 $key 不是完整 URL');
    }

    return uri;
  }

  static String _stringOrFallback(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }

    return null;
  }
}
