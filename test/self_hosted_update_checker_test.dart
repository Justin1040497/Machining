import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:framelean/infrastructure/services/update/self_hosted_update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HmacUpdateRequestAuthenticator', () {
    test('signs request path, query, timestamp, nonce and body hash', () {
      final signature = HmacUpdateRequestAuthenticator.sign(
        secret: 'secret',
        method: 'GET',
        uri: Uri.parse(
          'https://updates.example.com/api/v1/updates/check?platform=macos-arm64&current_version=1.1.5',
        ),
        timestamp: '1760000000',
        nonce: 'nonce',
      );

      expect(
        signature,
        '149b15425241fd863011e5eda48d77ca4cbdfbc02175ed2ae41ac9fc14b2f98d',
      );
    });

    test('adds HMAC headers', () async {
      final authenticator = HmacUpdateRequestAuthenticator(
        secret: 'secret',
        clientIdStore: MemoryUpdateClientIdStore('client-1'),
        clock: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
        nonceFactory: () => 'nonce',
      );

      final headers = await authenticator.signedHeaders(
        method: 'GET',
        uri: Uri.parse(
          'https://updates.example.com/api/v1/releases/1.1.6/notes',
        ),
      );

      expect(headers['X-FrameLean-Client-Id'], 'client-1');
      expect(headers['X-FrameLean-Timestamp'], '1760000000');
      expect(headers['X-FrameLean-Nonce'], 'nonce');
      expect(headers['X-FrameLean-Signature'], isNotEmpty);
    });
  });

  group('SelfHostedUpdateChecker', () {
    test('checks version, then fetches release notes and package', () async {
      final requests = <http.Request>[];
      final checker = _checker(
        MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/api/v1/updates/check' => _jsonResponse(_checkUpdateJson()),
            '/api/v1/releases/1.1.6/notes' => http.Response.bytes(
              utf8.encode('## 更新内容\n- 新增鉴权更新服务'),
              200,
              headers: {'content-type': 'text/markdown; charset=utf-8'},
            ),
            '/api/v1/releases/1.1.6/packages/macos-arm64' => _jsonResponse(
              _packageJson(),
            ),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final result = await checker.checkForUpdates(
        currentVersion: AppVersion.parse('1.1.5'),
        platform: AppUpdatePlatform.macosArm64,
      );

      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, AppVersion.parse('1.1.6'));
      expect(result.latestRelease?.releaseNotes, contains('新增鉴权更新服务'));
      expect(result.latestRelease?.packageAsset.name, 'FrameLean-v1.1.6.dmg');
      expect(
        requests.first.url.toString(),
        'https://updates.example.com/api/v1/updates/check?platform=macos-arm64&current_version=1.1.5',
      );
      for (final request in requests) {
        expect(request.headers['X-FrameLean-Client-Id'], 'client-1');
        expect(request.headers['X-FrameLean-Signature'], isNotEmpty);
      }
    });

    test('returns no update without fetching notes or package', () async {
      final requests = <http.Request>[];
      final checker = _checker(
        MockClient((request) async {
          requests.add(request);
          return _jsonResponse({
            'schemaVersion': 1,
            'updateAvailable': false,
            'currentVersion': '1.1.6',
            'latestVersion': '1.1.6',
            'latestRelease': null,
          });
        }),
      );

      final result = await checker.checkForUpdates(
        currentVersion: AppVersion.parse('1.1.6'),
        platform: AppUpdatePlatform.windowsX64,
      );

      expect(result.updateAvailable, isFalse);
      expect(result.latestRelease, isNull);
      expect(requests, hasLength(1));
      expect(requests.single.url.query, contains('platform=windows-x64'));
    });

    test('reports HTTP errors without exposing provider details', () async {
      final checker = _checker(
        MockClient((request) async {
          return http.Response('server error', 500);
        }),
      );

      expect(
        () => checker.checkForUpdates(
          currentVersion: AppVersion.parse('1.1.5'),
          platform: AppUpdatePlatform.macosArm64,
        ),
        throwsA(
          isA<AppUpdateException>()
              .having(
                (error) => error.technicalDetail,
                'technical detail',
                contains('HTTP 500'),
              )
              .having(
                (error) => error.userMessage,
                'user message',
                '暂时无法检查更新，请稍后重试',
              ),
        ),
      );
    });

    test('describes TLS failures as update endpoint failures', () async {
      final checker = _checker(
        MockClient((request) async {
          throw const HandshakeException(
            'Connection terminated during handshake',
          );
        }),
      );

      expect(
        () => checker.checkForUpdates(
          currentVersion: AppVersion.parse('1.1.5'),
          platform: AppUpdatePlatform.macosArm64,
        ),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.technicalDetail,
            'technical detail',
            contains('更新接口 TLS 握手失败'),
          ),
        ),
      );
    });
  });
}

SelfHostedUpdateChecker _checker(http.Client httpClient) {
  return SelfHostedUpdateChecker(
    apiBaseUri: Uri.parse('https://updates.example.com'),
    authenticator: HmacUpdateRequestAuthenticator(
      secret: 'secret',
      clientIdStore: MemoryUpdateClientIdStore('client-1'),
      clock: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
      nonceFactory: () => 'nonce',
    ),
    httpClient: httpClient,
  );
}

http.Response _jsonResponse(Object? json) {
  return http.Response.bytes(utf8.encode(jsonEncode(json)), 200);
}

Map<String, Object?> _checkUpdateJson() {
  return {
    'schemaVersion': 1,
    'updateAvailable': true,
    'currentVersion': '1.1.5',
    'latestVersion': '1.1.6',
    'latestRelease': {
      'version': '1.1.6',
      'title': 'FrameLean v1.1.6',
      'notesUrl': 'https://updates.example.com/api/v1/releases/1.1.6/notes',
      'packageUrl':
          'https://updates.example.com/api/v1/releases/1.1.6/packages/macos-arm64',
      'releasePageUrl': 'https://framelean.example.com/releases/1.1.6',
    },
  };
}

Map<String, Object?> _packageJson() {
  return {
    'schemaVersion': 1,
    'platform': 'macos-arm64',
    'version': '1.1.6',
    'package': {
      'name': 'FrameLean-v1.1.6.dmg',
      'downloadUrl':
          'https://updates.example.com/api/v1/releases/1.1.6/packages/macos-arm64/download?token=abc',
      'sizeBytes': 123,
      'sha256': 'abc123',
    },
  };
}
