import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class HttpAppUpdateClient implements AppUpdateClient {
  HttpAppUpdateClient({required this.baseUri, HttpClient? httpClient})
    : httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final HttpClient httpClient;

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
    final uri = _resolve(
      '/api/v1/releases/latest',
      queryParameters: {
        'currentVersion': currentVersion,
        'currentBuild': currentBuild.toString(),
        'platform': platform,
        'channel': channel,
      },
    );
    final json = await _readJsonObject(uri);
    final updateAvailable = json['updateAvailable'] == true;
    if (!updateAvailable) {
      return const AppUpdateCheckResult(updateAvailable: false);
    }

    final releaseJson = json['release'];
    if (releaseJson is! Map<String, Object?>) {
      throw const FormatException('更新响应缺少 release 字段');
    }

    final notesUrl = releaseJson['notesUrl'] as String? ?? '';
    final notesMarkdown = notesUrl.isEmpty
        ? ''
        : await _readText(_resolve(notesUrl));
    final summary = _summarizeMarkdown(notesMarkdown);

    return AppUpdateCheckResult(
      updateAvailable: true,
      release: _releaseFromJson(
        releaseJson,
        platform: platform,
        notesMarkdown: notesMarkdown,
        notesSummary: summary,
      ),
    );
  }

  @override
  Future<AppUpdateDownloadTicket> createDownloadTicket({
    required AppReleaseInfo release,
    required String installId,
  }) async {
    final createJson = await _readJsonObject(
      _resolve('/api/v1/releases/download-ticket'),
      method: 'POST',
      body: {
        'version': release.version,
        'platform': release.platform,
        'installId': installId,
      },
    );
    final ticketId = createJson['ticketId'] as String;
    final json = await _readJsonObject(
      _resolve(
        '/api/v1/releases/download-ticket/${Uri.encodeComponent(ticketId)}/resolve',
      ),
      method: 'POST',
    );
    return AppUpdateDownloadTicket(
      downloadUrl: Uri.parse(json['downloadUrl'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      package: AppUpdatePackageInfo(
        fileName: json['fileName'] as String,
        sizeBytes: (json['size'] as num).toInt(),
        sha256: json['sha256'] as String,
        ed25519Signature: json['ed25519Signature'] as String?,
      ),
    );
  }

  @override
  Future<String> loadReleaseNotes(AppReleaseInfo release) async {
    if (release.releaseNotesMarkdown.trim().isNotEmpty) {
      return release.releaseNotesMarkdown;
    }
    return _readText(_resolve(release.notesUrl));
  }

  @override
  Future<List<AppReleaseNotes>> loadReleaseNotesList({
    required String channel,
  }) async {
    final uri = _resolve(
      '/api/v1/releases/notes',
      queryParameters: {'channel': channel},
    );
    final json = await _readJson(uri);
    if (json is! List) {
      throw const FormatException('版本日志响应必须是列表');
    }

    return [
      for (final item in json)
        if (item is Map<String, Object?>)
          AppReleaseNotes(
            version: item['version'] as String,
            buildNumber: (item['buildNumber'] as num).toInt(),
            channel: item['channel'] as String? ?? channel,
            publishedAt: item['publishedAt'] == null
                ? null
                : DateTime.tryParse(item['publishedAt'] as String),
            markdown: item['notes'] as String? ?? '',
            summary: item['summary'] as String? ?? '',
          ),
    ];
  }

  Uri _resolve(String path, {Map<String, String>? queryParameters}) {
    final rawPath = path.startsWith('/') ? path : '/$path';
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(
      path: '$basePath$rawPath',
      queryParameters: queryParameters,
    );
  }

  Future<Object?> _readJson(Uri uri) async {
    final text = await _readText(uri);
    return jsonDecode(text);
  }

  Future<Map<String, Object?>> _readJsonObject(
    Uri uri, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final request = await httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('更新服务返回 ${response.statusCode}: $text', uri: uri);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('更新服务响应必须是 JSON 对象');
    }
    return decoded;
  }

  Future<String> _readText(Uri uri) async {
    final request = await httpClient.getUrl(uri);
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('更新服务返回 ${response.statusCode}: $text', uri: uri);
    }
    return text;
  }

  AppReleaseInfo _releaseFromJson(
    Map<String, Object?> json, {
    required String platform,
    required String notesMarkdown,
    required String notesSummary,
  }) {
    return AppReleaseInfo(
      version: json['version'] as String,
      buildNumber: (json['buildNumber'] as num).toInt(),
      channel: json['channel'] as String? ?? 'stable',
      platform: platform,
      mandatory: json['mandatory'] == true,
      minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 0,
      notesUrl: json['notesUrl'] as String? ?? '',
      releaseNotesMarkdown: notesMarkdown,
      releaseNotesSummary: notesSummary,
      package: AppUpdatePackageInfo(
        fileName: json['fileName'] as String,
        sizeBytes: (json['size'] as num).toInt(),
        sha256: json['sha256'] as String,
        ed25519Signature: json['ed25519Signature'] as String?,
      ),
    );
  }
}

String _summarizeMarkdown(String markdown) {
  final lines = markdown
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  if (lines.isEmpty) {
    return '查看版本日志了解本次更新内容。';
  }
  final first = lines.first.replaceFirst(RegExp(r'^[-*]\s+'), '');
  if (first.length <= 72) {
    return first;
  }
  return '${first.substring(0, 72)}...';
}
