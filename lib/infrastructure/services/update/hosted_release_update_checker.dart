import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:http/http.dart' as http;

class HostedReleaseUpdateChecker implements AppUpdateChecker {
  HostedReleaseUpdateChecker({
    required List<HostedReleaseUpdateSource> sources,
    http.Client? httpClient,
    Duration? requestTimeout,
    Duration? primarySourceGracePeriod,
  }) : _httpClient = httpClient ?? http.Client(),
       _sources = List.unmodifiable(sources),
       requestTimeout = requestTimeout ?? const Duration(seconds: 4),
       primarySourceGracePeriod =
           primarySourceGracePeriod ?? const Duration(milliseconds: 1200);

  factory HostedReleaseUpdateChecker.frameLean({http.Client? httpClient}) {
    return HostedReleaseUpdateChecker(
      httpClient: httpClient,
      sources: [
        HostedReleaseUpdateSource.frameLeanGitee(),
        HostedReleaseUpdateSource.frameLeanGitHub(),
      ],
    );
  }

  final http.Client _httpClient;
  final List<HostedReleaseUpdateSource> _sources;
  final Duration requestTimeout;
  final Duration primarySourceGracePeriod;

  @override
  Future<AppUpdateCheckResult> checkForUpdates({
    required AppVersion currentVersion,
    required AppUpdatePlatform platform,
  }) async {
    final release = await _fetchFirstAvailableRelease(platform: platform);

    return AppUpdateCheckResult(
      currentVersion: currentVersion,
      latestRelease: release,
    );
  }

  Future<AppUpdateRelease> _fetchFirstAvailableRelease({
    required AppUpdatePlatform platform,
  }) async {
    if (_sources.isEmpty) {
      throw const AppUpdateException('检查更新失败: 未配置更新源');
    }

    var nextId = 0;
    final failures = <AppUpdateException>[];
    final pending = <_PendingReleaseFetch>[
      _PendingReleaseFetch(
        id: nextId++,
        future: _fetchSourceOutcome(_sources.first, platform: platform),
      ),
    ];

    if (_sources.length > 1 && primarySourceGracePeriod > Duration.zero) {
      final firstOutcome = await Future.any<Object?>([
        pending.first.future,
        Future<void>.delayed(primarySourceGracePeriod),
      ]);

      if (firstOutcome is _ReleaseSourceOutcome) {
        pending.clear();
        if (firstOutcome.release != null) {
          return firstOutcome.release!;
        }
        failures.add(firstOutcome.exception!);
      }
    }

    for (var index = 1; index < _sources.length; index++) {
      pending.add(
        _PendingReleaseFetch(
          id: nextId++,
          future: _fetchSourceOutcome(_sources[index], platform: platform),
        ),
      );
    }

    return _awaitFirstSuccessfulRelease(pending: pending, failures: failures);
  }

  Future<AppUpdateRelease> _awaitFirstSuccessfulRelease({
    required List<_PendingReleaseFetch> pending,
    required List<AppUpdateException> failures,
  }) async {
    while (pending.isNotEmpty) {
      final completed = await Future.any(
        pending.map((fetch) async {
          final outcome = await fetch.future;
          return _CompletedReleaseFetch(id: fetch.id, outcome: outcome);
        }),
      );
      pending.removeWhere((fetch) => fetch.id == completed.id);

      final release = completed.outcome.release;
      if (release != null) {
        return release;
      }

      failures.add(completed.outcome.exception!);
    }

    throw AppUpdateException(_failureMessage(failures));
  }

  Future<_ReleaseSourceOutcome> _fetchSourceOutcome(
    HostedReleaseUpdateSource source, {
    required AppUpdatePlatform platform,
  }) async {
    try {
      final release = await _fetchLatestRelease(source, platform: platform);
      return _ReleaseSourceOutcome.success(release);
    } on AppUpdateException catch (error) {
      return _ReleaseSourceOutcome.failure(_withSourceName(source, error));
    } on Object catch (error) {
      return _ReleaseSourceOutcome.failure(
        AppUpdateException(
          '${source.name}: ${_describeConnectionError(error)}',
        ),
      );
    }
  }

  Future<AppUpdateRelease> _fetchLatestRelease(
    HostedReleaseUpdateSource source, {
    required AppUpdatePlatform platform,
  }) async {
    try {
      final response = await _httpClient
          .get(source.latestReleaseUri, headers: source.headers)
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException(_describeHttpError(source, response));
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final releaseJson = source.parseReleaseJson(decoded);

      return HostedReleaseUpdateParser.parseLatestRelease(
        releaseJson,
        platform: platform,
        assetBaseUri: source.latestReleaseUri,
        releasePageUriForTag: source.releasePageUriForTag,
      );
    } on AppUpdateException {
      rethrow;
    } on FormatException {
      throw AppUpdateException('${source.name}: Release 响应格式无效');
    } on TimeoutException {
      throw AppUpdateException('${source.name}: 连接超时');
    } on HandshakeException {
      throw AppUpdateException('${source.name}: TLS 握手失败');
    } on SocketException catch (error) {
      throw AppUpdateException(
        '${source.name}: ${_describeSocketError(error)}',
      );
    } on Object catch (error) {
      throw AppUpdateException(
        '${source.name}: ${_describeConnectionError(error)}',
      );
    }
  }

  static AppUpdateException _withSourceName(
    HostedReleaseUpdateSource source,
    AppUpdateException error,
  ) {
    if (error.message.startsWith('${source.name}:')) {
      return error;
    }

    final message = error.message
        .replaceFirst(RegExp(r'^检查更新失败:?\s*'), '')
        .trim();
    return AppUpdateException('${source.name}: $message');
  }

  static String _describeHttpError(
    HostedReleaseUpdateSource source,
    http.Response response,
  ) {
    if (response.statusCode == 404) {
      return '${source.name}: 没有找到发布版本（HTTP 404）';
    }

    return '${source.name}: HTTP ${response.statusCode}';
  }

  static String _describeConnectionError(Object error) {
    if (error is TimeoutException) {
      return '连接超时';
    }
    if (error is HandshakeException) {
      return 'TLS 握手失败';
    }
    if (error is SocketException) {
      return _describeSocketError(error);
    }

    final message = error.toString();
    if (message.contains('HandshakeException')) {
      return 'TLS 握手失败';
    }
    if (message.contains('TimeoutException')) {
      return '连接超时';
    }
    if (message.contains('SocketException')) {
      return '网络连接失败';
    }

    return '网络连接失败';
  }

  static String _describeSocketError(SocketException error) {
    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('nodename nor servname') ||
        message.contains('name or service not known')) {
      return 'DNS 解析失败';
    }
    if (message.contains('connection refused')) {
      return '连接被拒绝';
    }
    if (message.contains('connection timed out')) {
      return '连接超时';
    }

    return '网络连接失败';
  }

  static String _failureMessage(List<AppUpdateException> failures) {
    if (failures.isEmpty) {
      return '检查更新失败: 更新源不可用';
    }

    final details = failures
        .map((failure) => failure.message)
        .toSet()
        .join('；');
    return '检查更新失败: $details';
  }
}

class HostedReleaseUpdateSource {
  const HostedReleaseUpdateSource({
    required this.name,
    required this.latestReleaseUri,
    required this.headers,
    required this.responseShape,
    required this.releasePageUriForTag,
  });

  factory HostedReleaseUpdateSource.frameLeanGitee() {
    return HostedReleaseUpdateSource(
      name: 'Gitee',
      latestReleaseUri: Uri.parse(
        'https://gitee.com/api/v5/repos/zhouycheng/FrameLean/releases?per_page=1&page=1',
      ),
      headers: const {'Accept': 'application/json', 'User-Agent': 'FrameLean'},
      responseShape: HostedReleaseResponseShape.releaseList,
      releasePageUriForTag: (tagName) => Uri.parse(
        'https://gitee.com/zhouycheng/FrameLean/releases/tag/$tagName',
      ),
    );
  }

  factory HostedReleaseUpdateSource.frameLeanGitHub() {
    return HostedReleaseUpdateSource(
      name: 'GitHub',
      latestReleaseUri: Uri.parse(
        'https://api.github.com/repos/zhouycheng/FrameLean/releases/latest',
      ),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'FrameLean',
      },
      responseShape: HostedReleaseResponseShape.latestRelease,
      releasePageUriForTag: (tagName) => Uri.parse(
        'https://github.com/zhouycheng/FrameLean/releases/tag/$tagName',
      ),
    );
  }

  final String name;
  final Uri latestReleaseUri;
  final Map<String, String> headers;
  final HostedReleaseResponseShape responseShape;
  final Uri Function(String tagName) releasePageUriForTag;

  Map<String, Object?> parseReleaseJson(Object? decoded) {
    return switch (responseShape) {
      HostedReleaseResponseShape.latestRelease => _parseLatestRelease(decoded),
      HostedReleaseResponseShape.releaseList => _parseReleaseList(decoded),
    };
  }

  Map<String, Object?> _parseLatestRelease(Object? decoded) {
    if (decoded is Map<String, Object?>) {
      return decoded;
    }

    throw const AppUpdateException('Release 响应格式无效');
  }

  Map<String, Object?> _parseReleaseList(Object? decoded) {
    if (decoded is! List<Object?>) {
      throw const AppUpdateException('Release 列表格式无效');
    }
    if (decoded.isEmpty) {
      throw const AppUpdateException('没有发布版本');
    }

    final release = decoded.first;
    if (release is Map<String, Object?>) {
      return release;
    }

    throw const AppUpdateException('Release 响应格式无效');
  }
}

enum HostedReleaseResponseShape { latestRelease, releaseList }

abstract final class HostedReleaseUpdateParser {
  static AppUpdateRelease parseLatestRelease(
    Map<String, Object?> json, {
    required AppUpdatePlatform platform,
    required Uri Function(String tagName) releasePageUriForTag,
    Uri? assetBaseUri,
  }) {
    final tagName = _requiredString(json, 'tag_name');
    final releasePageUrl =
        _optionalUri(json['html_url']) ??
        _optionalUri(json['url']) ??
        releasePageUriForTag(tagName);
    final title = _stringOrFallback(json['name'], tagName);
    final releaseNotes = _stringOrFallback(
      json['body'],
      _stringOrFallback(json['description'], ''),
    );
    final assets = _requiredAssets(json, assetBaseUri: assetBaseUri);
    final packageAsset = _findPackageAsset(assets, platform: platform);
    if (packageAsset == null) {
      throw const AppUpdateException('最新版本缺少可用的 macOS DMG 安装包');
    }

    return AppUpdateRelease(
      version: AppVersion.parse(tagName),
      title: title,
      releaseNotes: releaseNotes,
      releasePageUrl: releasePageUrl,
      packageAsset: packageAsset,
      checksumAsset: _findChecksumAsset(assets, packageAsset.name),
    );
  }

  static List<AppUpdateAsset> _requiredAssets(
    Map<String, Object?> json, {
    Uri? assetBaseUri,
  }) {
    final assetsValue =
        json['assets'] ?? json['attach_files'] ?? json['attachments'];
    if (assetsValue is! List<Object?>) {
      throw const AppUpdateException('检查更新失败: Release 资源列表格式无效');
    }

    return assetsValue
        .map((assetValue) {
          if (assetValue is! Map<String, Object?>) {
            throw const AppUpdateException('检查更新失败: Release 资源格式无效');
          }

          return AppUpdateAsset(
            name: _requiredString(assetValue, 'name'),
            downloadUrl: _requiredUri(assetValue, const [
              'browser_download_url',
              'download_url',
              'url',
            ], baseUri: assetBaseUri),
            sizeBytes: _optionalInt(assetValue['size']),
          );
        })
        .toList(growable: false);
  }

  static AppUpdateAsset? _findPackageAsset(
    List<AppUpdateAsset> assets, {
    required AppUpdatePlatform platform,
  }) {
    return switch (platform) {
      AppUpdatePlatform.macosArm64 => _firstWhereOrNull(assets, (asset) {
        final name = asset.name.toLowerCase();
        return name.startsWith('framelean-v') && name.endsWith('.dmg');
      }),
    };
  }

  static AppUpdateAsset? _findChecksumAsset(
    List<AppUpdateAsset> assets,
    String packageName,
  ) {
    final expectedName = '$packageName.sha256'.toLowerCase();
    return _firstWhereOrNull(
      assets,
      (asset) => asset.name.toLowerCase() == expectedName,
    );
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }

    return null;
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw AppUpdateException('检查更新失败: Release 缺少 $key');
  }

  static Uri _requiredUri(
    Map<String, Object?> json,
    List<String> keys, {
    Uri? baseUri,
  }) {
    for (final key in keys) {
      final uri = _optionalUri(json[key], baseUri: baseUri);
      if (uri != null) {
        return uri;
      }
    }

    throw AppUpdateException('检查更新失败: Release 缺少 ${keys.join('/')}');
  }

  static Uri? _optionalUri(Object? value, {Uri? baseUri}) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    final parsed = Uri.parse(value.trim());
    if (parsed.hasScheme) {
      return parsed;
    }

    return baseUri?.resolveUri(parsed);
  }

  static String _stringOrFallback(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }

    return null;
  }
}

class _PendingReleaseFetch {
  const _PendingReleaseFetch({required this.id, required this.future});

  final int id;
  final Future<_ReleaseSourceOutcome> future;
}

class _CompletedReleaseFetch {
  const _CompletedReleaseFetch({required this.id, required this.outcome});

  final int id;
  final _ReleaseSourceOutcome outcome;
}

class _ReleaseSourceOutcome {
  const _ReleaseSourceOutcome._({this.release, this.exception});

  factory _ReleaseSourceOutcome.success(AppUpdateRelease release) {
    return _ReleaseSourceOutcome._(release: release);
  }

  factory _ReleaseSourceOutcome.failure(AppUpdateException exception) {
    return _ReleaseSourceOutcome._(exception: exception);
  }

  final AppUpdateRelease? release;
  final AppUpdateException? exception;
}
