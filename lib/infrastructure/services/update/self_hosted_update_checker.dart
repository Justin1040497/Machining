import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef UpdateClock = DateTime Function();
typedef UpdateNonceFactory = String Function();

class SelfHostedUpdateChecker implements AppUpdateChecker {
  SelfHostedUpdateChecker({
    required Uri apiBaseUri,
    required HmacUpdateRequestAuthenticator authenticator,
    http.Client? httpClient,
    Duration? requestTimeout,
  }) : apiBaseUri = _normalizeBaseUri(apiBaseUri),
       _authenticator = authenticator,
       _httpClient = httpClient ?? http.Client(),
       requestTimeout = requestTimeout ?? const Duration(seconds: 6);

  factory SelfHostedUpdateChecker.frameLean({http.Client? httpClient}) {
    const baseUrl = String.fromEnvironment(
      'FRAMELEAN_UPDATE_BASE_URL',
      defaultValue: 'https://framelean-updates.example.com',
    );
    const secret = String.fromEnvironment('FRAMELEAN_UPDATE_HMAC_SECRET');

    return SelfHostedUpdateChecker(
      apiBaseUri: Uri.parse(baseUrl),
      authenticator: HmacUpdateRequestAuthenticator(
        secret: secret,
        clientIdStore: FileUpdateClientIdStore(),
      ),
      httpClient: httpClient,
    );
  }

  final Uri apiBaseUri;
  final HmacUpdateRequestAuthenticator _authenticator;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<AppUpdateCheckResult> checkForUpdates({
    required AppVersion currentVersion,
    required AppUpdatePlatform platform,
  }) async {
    final check = await _fetchUpdateCheck(
      currentVersion: currentVersion,
      platform: platform,
    );

    if (!check.updateAvailable || check.latestRelease == null) {
      return AppUpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: check.latestVersion,
      );
    }

    final summary = check.latestRelease!;
    final releaseNotes = await _fetchReleaseNotes(summary.notesUrl);
    final packageAsset = await _fetchPackageAsset(summary.packageUrl);

    return AppUpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: check.latestVersion,
      latestRelease: AppUpdateRelease(
        version: summary.version,
        title: summary.title,
        releaseNotes: releaseNotes,
        releasePageUrl: summary.releasePageUrl,
        packageAsset: packageAsset,
      ),
    );
  }

  Future<_UpdateCheckPayload> _fetchUpdateCheck({
    required AppVersion currentVersion,
    required AppUpdatePlatform platform,
  }) async {
    final uri = _apiUri(
      '/api/v1/updates/check',
      queryParameters: {
        'platform': platform.updateApiValue,
        'current_version': currentVersion.toString(),
      },
    );
    final decoded = await _getJson(uri);
    return SelfHostedUpdateParser._parseUpdateCheck(decoded);
  }

  Future<String> _fetchReleaseNotes(Uri uri) async {
    final response = await _get(uri);
    return utf8.decode(response.bodyBytes).trim();
  }

  Future<AppUpdateAsset> _fetchPackageAsset(Uri uri) async {
    final decoded = await _getJson(uri);
    return SelfHostedUpdateParser.parsePackageAsset(decoded);
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await _get(uri);
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const AppUpdateException('更新接口响应格式无效');
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final headers = await _authenticator.signedHeaders(
        method: 'GET',
        uri: uri,
      );
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException('更新接口返回 HTTP ${response.statusCode}');
      }

      return response;
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException('更新接口连接超时');
    } on HandshakeException {
      throw const AppUpdateException('更新接口 TLS 握手失败');
    } on SocketException catch (error) {
      throw AppUpdateException(_describeSocketError(error));
    } on Object catch (error) {
      throw AppUpdateException('更新接口网络连接失败: $error');
    }
  }

  Uri _apiUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$apiBaseUri$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  static Uri _normalizeBaseUri(Uri uri) {
    final value = uri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse(value);
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

class HmacUpdateRequestAuthenticator {
  HmacUpdateRequestAuthenticator({
    required this.secret,
    required this.clientIdStore,
    UpdateClock? clock,
    UpdateNonceFactory? nonceFactory,
  }) : _clock = clock ?? DateTime.now,
       _nonceFactory = nonceFactory ?? (() => const Uuid().v4());

  final String secret;
  final UpdateClientIdStore clientIdStore;
  final UpdateClock _clock;
  final UpdateNonceFactory _nonceFactory;

  Future<Map<String, String>> signedHeaders({
    required String method,
    required Uri uri,
    List<int> bodyBytes = const [],
  }) async {
    if (secret.trim().isEmpty) {
      throw const AppUpdateException('更新接口鉴权配置缺失');
    }

    final clientId = await clientIdStore.readClientId();
    final timestamp = (_clock().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _nonceFactory();
    final signature = sign(
      secret: secret,
      method: method,
      uri: uri,
      timestamp: timestamp,
      nonce: nonce,
      bodyBytes: bodyBytes,
    );

    return {
      'Accept': 'application/json, text/markdown',
      'User-Agent': 'FrameLean',
      'X-FrameLean-Client-Id': clientId,
      'X-FrameLean-Timestamp': timestamp,
      'X-FrameLean-Nonce': nonce,
      'X-FrameLean-Signature': signature,
    };
  }

  static String sign({
    required String secret,
    required String method,
    required Uri uri,
    required String timestamp,
    required String nonce,
    List<int> bodyBytes = const [],
  }) {
    final bodyHash = sha256.convert(bodyBytes).toString();
    final payload = [
      method.toUpperCase(),
      _pathWithQuery(uri),
      timestamp,
      nonce,
      bodyHash,
    ].join('\n');
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  static String _pathWithQuery(Uri uri) {
    if (uri.hasQuery) {
      return '${uri.path}?${uri.query}';
    }

    return uri.path;
  }
}

abstract interface class UpdateClientIdStore {
  Future<String> readClientId();
}

class FileUpdateClientIdStore implements UpdateClientIdStore {
  FileUpdateClientIdStore({this.fileName = 'update-client-id.txt'});

  final String fileName;

  @override
  Future<String> readClientId() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, fileName));
    if (await file.exists()) {
      final existing = (await file.readAsString()).trim();
      if (existing.isNotEmpty) {
        return existing;
      }
    }

    final clientId = const Uuid().v4();
    await file.parent.create(recursive: true);
    await file.writeAsString(clientId);
    return clientId;
  }
}

class MemoryUpdateClientIdStore implements UpdateClientIdStore {
  MemoryUpdateClientIdStore(this.clientId);

  final String clientId;

  @override
  Future<String> readClientId() async => clientId;
}

abstract final class SelfHostedUpdateParser {
  static _UpdateCheckPayload _parseUpdateCheck(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      throw const AppUpdateException('更新接口响应格式无效');
    }

    final updateAvailable = _requiredBool(decoded, 'updateAvailable');
    final latestVersion = AppVersion.parse(
      _requiredString(decoded, 'latestVersion'),
    );
    final releaseJson = _optionalObject(decoded['latestRelease']);

    return _UpdateCheckPayload(
      updateAvailable: updateAvailable,
      latestVersion: latestVersion,
      latestRelease: releaseJson == null
          ? null
          : _parseReleaseSummary(releaseJson),
    );
  }

  static AppUpdateAsset parsePackageAsset(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      throw const AppUpdateException('更新接口响应格式无效');
    }

    final packageJson = _requiredObject(decoded, 'package');
    return AppUpdateAsset(
      name: _requiredString(packageJson, 'name'),
      downloadUrl: _requiredUri(packageJson, 'downloadUrl'),
      sizeBytes: _optionalInt(packageJson['sizeBytes']),
      sha256: _optionalString(packageJson['sha256']),
    );
  }

  static _UpdateReleaseSummary _parseReleaseSummary(
    Map<String, Object?> decoded,
  ) {
    final notesUrl = _requiredUri(decoded, 'notesUrl');
    return _UpdateReleaseSummary(
      version: AppVersion.parse(_requiredString(decoded, 'version')),
      title: _requiredString(decoded, 'title'),
      notesUrl: notesUrl,
      packageUrl: _requiredUri(decoded, 'packageUrl'),
      releasePageUrl: _optionalUri(decoded['releasePageUrl']) ?? notesUrl,
    );
  }

  static bool _requiredBool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }

    throw AppUpdateException('更新接口响应缺少 $key');
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

  static Uri? _optionalUri(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    final uri = Uri.parse(value.trim());
    if (!uri.hasScheme) {
      throw const AppUpdateException('更新接口响应格式无效');
    }

    return uri;
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

class _UpdateCheckPayload {
  const _UpdateCheckPayload({
    required this.updateAvailable,
    required this.latestVersion,
    this.latestRelease,
  });

  final bool updateAvailable;
  final AppVersion latestVersion;
  final _UpdateReleaseSummary? latestRelease;
}

class _UpdateReleaseSummary {
  const _UpdateReleaseSummary({
    required this.version,
    required this.title,
    required this.notesUrl,
    required this.packageUrl,
    required this.releasePageUrl,
  });

  final AppVersion version;
  final String title;
  final Uri notesUrl;
  final Uri packageUrl;
  final Uri releasePageUrl;
}
