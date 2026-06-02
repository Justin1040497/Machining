import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:framelean/infrastructure/services/update/update_manifest_update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('UpdateManifestParser', () {
    test('parses latest macOS update payload', () {
      final release = UpdateManifestParser.parseLatestUpdate(
        _latestUpdateJson(),
      );

      expect(release.version, AppVersion.parse('1.1.6'));
      expect(release.title, 'FrameLean v1.1.6');
      expect(release.releaseNotes, contains('新增检查更新'));
      expect(
        release.releasePageUrl.toString(),
        'https://framelean.example.com/releases/v1.1.6',
      );
      expect(release.packageAsset.name, 'FrameLean-v1.1.6.dmg');
      expect(release.packageAsset.sizeBytes, 123);
      expect(release.packageAsset.sha256, 'abc123');
      expect(release.checksumAsset?.name, 'FrameLean-v1.1.6.dmg.sha256');
    });

    test('reports missing package payload', () {
      final json = _latestUpdateJson()..remove('package');

      expect(
        () => UpdateManifestParser.parseLatestUpdate(json),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('identifies available updates from parsed release', () {
      final release = UpdateManifestParser.parseLatestUpdate(
        _latestUpdateJson(),
      );
      final result = AppUpdateCheckResult(
        currentVersion: AppVersion.parse('1.1.5'),
        latestRelease: release,
      );

      expect(result.updateAvailable, isTrue);
    });
  });

  group('UpdateManifestUpdateChecker', () {
    test(
      'requests the configured update endpoint with platform query',
      () async {
        final requests = <Uri>[];
        final checker = UpdateManifestUpdateChecker(
          latestUpdateUri: Uri.parse(
            'https://updates.example.com/v1/updates/latest?channel=stable',
          ),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return _jsonResponse(_latestUpdateJson());
          }),
        );

        final result = await checker.checkForUpdates(
          currentVersion: AppVersion.parse('1.1.5'),
          platform: AppUpdatePlatform.macosArm64,
        );

        expect(result.latestRelease.version, AppVersion.parse('1.1.6'));
        expect(requests.single.toString(), contains('channel=stable'));
        expect(requests.single.toString(), contains('platform=macos-arm64'));
      },
    );

    test('reports HTTP errors without exposing provider details', () async {
      final checker = UpdateManifestUpdateChecker(
        latestUpdateUri: Uri.parse(
          'https://updates.example.com/v1/updates/latest',
        ),
        httpClient: MockClient((request) async {
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
      final checker = UpdateManifestUpdateChecker(
        latestUpdateUri: Uri.parse(
          'https://updates.example.com/v1/updates/latest',
        ),
        httpClient: MockClient((request) async {
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

http.Response _jsonResponse(Object? json) {
  return http.Response.bytes(utf8.encode(jsonEncode(json)), 200);
}

Map<String, Object?> _latestUpdateJson() {
  return {
    'schemaVersion': 1,
    'platform': 'macos-arm64',
    'version': 'v1.1.6',
    'title': 'FrameLean v1.1.6',
    'releaseNotes': '## 更新内容\n- 新增检查更新',
    'releasePageUrl': 'https://framelean.example.com/releases/v1.1.6',
    'package': {
      'name': 'FrameLean-v1.1.6.dmg',
      'downloadUrl':
          'https://downloads.example.com/releases/v1.1.6/FrameLean-v1.1.6.dmg',
      'sizeBytes': 123,
      'sha256': 'abc123',
    },
    'checksum': {
      'name': 'FrameLean-v1.1.6.dmg.sha256',
      'downloadUrl':
          'https://downloads.example.com/releases/v1.1.6/FrameLean-v1.1.6.dmg.sha256',
      'sizeBytes': 64,
    },
  };
}
