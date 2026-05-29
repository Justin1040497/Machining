import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:framelean/infrastructure/services/update/hosted_release_update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HostedReleaseUpdateParser', () {
    test('parses latest macOS release assets and notes', () {
      final release = HostedReleaseUpdateParser.parseLatestRelease(
        {
          'tag_name': 'v1.1.6',
          'name': 'FrameLean v1.1.6',
          'body': '## 更新内容\n- 新增检查更新',
          'html_url':
              'https://github.com/zhouycheng/FrameLean/releases/tag/v1.1.6',
          'assets': [
            {
              'name': 'FrameLean-v1.1.6.dmg',
              'browser_download_url':
                  'https://github.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg',
              'size': 123,
            },
            {
              'name': 'FrameLean-v1.1.6.dmg.sha256',
              'browser_download_url':
                  'https://github.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg.sha256',
              'size': 64,
            },
          ],
        },
        platform: AppUpdatePlatform.macosArm64,
        releasePageUriForTag: _githubTag,
      );

      expect(release.version, AppVersion.parse('1.1.6'));
      expect(release.title, 'FrameLean v1.1.6');
      expect(release.releaseNotes, contains('新增检查更新'));
      expect(release.packageAsset.name, 'FrameLean-v1.1.6.dmg');
      expect(release.packageAsset.sizeBytes, 123);
      expect(release.checksumAsset?.name, 'FrameLean-v1.1.6.dmg.sha256');
    });

    test('parses Gitee release attachments and description', () {
      final release = HostedReleaseUpdateParser.parseLatestRelease(
        {
          'tag_name': 'v1.1.6',
          'name': 'FrameLean v1.1.6',
          'description': 'Gitee 更新说明',
          'attach_files': [
            {
              'name': 'FrameLean-v1.1.6.dmg',
              'download_url':
                  'https://gitee.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg',
              'size': 456,
            },
          ],
        },
        platform: AppUpdatePlatform.macosArm64,
        releasePageUriForTag: _giteeTag,
      );

      expect(release.version, AppVersion.parse('1.1.6'));
      expect(release.releaseNotes, 'Gitee 更新说明');
      expect(
        release.releasePageUrl.toString(),
        'https://gitee.com/zhouycheng/FrameLean/releases/tag/v1.1.6',
      );
      expect(release.packageAsset.name, 'FrameLean-v1.1.6.dmg');
      expect(release.packageAsset.sizeBytes, 456);
    });

    test('reports missing macOS dmg asset', () {
      expect(
        () => HostedReleaseUpdateParser.parseLatestRelease(
          {
            'tag_name': 'v1.1.6',
            'name': 'FrameLean v1.1.6',
            'body': '',
            'html_url':
                'https://github.com/zhouycheng/FrameLean/releases/tag/v1.1.6',
            'assets': <Object?>[],
          },
          platform: AppUpdatePlatform.macosArm64,
          releasePageUriForTag: _githubTag,
        ),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('identifies available updates from parsed release', () {
      final release = HostedReleaseUpdateParser.parseLatestRelease(
        {
          'tag_name': 'v1.1.6',
          'name': 'FrameLean v1.1.6',
          'body': '',
          'html_url':
              'https://github.com/zhouycheng/FrameLean/releases/tag/v1.1.6',
          'assets': [
            {
              'name': 'FrameLean-v1.1.6.dmg',
              'browser_download_url':
                  'https://github.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg',
              'size': 123,
            },
          ],
        },
        platform: AppUpdatePlatform.macosArm64,
        releasePageUriForTag: _githubTag,
      );
      final result = AppUpdateCheckResult(
        currentVersion: AppVersion.parse('1.1.5'),
        latestRelease: release,
      );

      expect(result.updateAvailable, isTrue);
    });
  });

  group('HostedReleaseUpdateChecker', () {
    test('uses Gitee when it returns before the grace period', () async {
      final requests = <Uri>[];
      final checker = HostedReleaseUpdateChecker(
        sources: [
          HostedReleaseUpdateSource.frameLeanGitee(),
          HostedReleaseUpdateSource.frameLeanGitHub(),
        ],
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return _jsonResponse([_giteeReleaseJson()]);
        }),
        primarySourceGracePeriod: const Duration(milliseconds: 50),
      );

      final result = await checker.checkForUpdates(
        currentVersion: AppVersion.parse('1.1.5'),
        platform: AppUpdatePlatform.macosArm64,
      );

      expect(result.latestRelease.version, AppVersion.parse('1.1.6'));
      expect(requests, [
        HostedReleaseUpdateSource.frameLeanGitee().latestReleaseUri,
      ]);
    });

    test('uses GitHub when Gitee is slower than the grace period', () async {
      final requests = <Uri>[];
      final checker = HostedReleaseUpdateChecker(
        sources: [
          HostedReleaseUpdateSource.frameLeanGitee(),
          HostedReleaseUpdateSource.frameLeanGitHub(),
        ],
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'gitee.com') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return _jsonResponse([_giteeReleaseJson()]);
          }

          return _jsonResponse(_githubReleaseJson());
        }),
        primarySourceGracePeriod: const Duration(milliseconds: 1),
      );

      final result = await checker.checkForUpdates(
        currentVersion: AppVersion.parse('1.1.5'),
        platform: AppUpdatePlatform.macosArm64,
      );

      expect(result.latestRelease.releasePageUrl.host, 'github.com');
      expect(
        requests,
        contains(HostedReleaseUpdateSource.frameLeanGitee().latestReleaseUri),
      );
      expect(
        requests,
        contains(HostedReleaseUpdateSource.frameLeanGitHub().latestReleaseUri),
      );
    });

    test('falls back to GitHub when Gitee returns an error', () async {
      final requests = <Uri>[];
      final checker = HostedReleaseUpdateChecker(
        sources: [
          HostedReleaseUpdateSource.frameLeanGitee(),
          HostedReleaseUpdateSource.frameLeanGitHub(),
        ],
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'gitee.com') {
            return http.Response('server error', 500);
          }

          return _jsonResponse(_githubReleaseJson());
        }),
      );

      final result = await checker.checkForUpdates(
        currentVersion: AppVersion.parse('1.1.5'),
        platform: AppUpdatePlatform.macosArm64,
      );

      expect(result.latestRelease.releasePageUrl.host, 'github.com');
      expect(requests, [
        HostedReleaseUpdateSource.frameLeanGitee().latestReleaseUri,
        HostedReleaseUpdateSource.frameLeanGitHub().latestReleaseUri,
      ]);
    });

    test('explains empty Gitee releases and GitHub TLS failures', () async {
      final checker = HostedReleaseUpdateChecker(
        sources: [
          HostedReleaseUpdateSource.frameLeanGitee(),
          HostedReleaseUpdateSource.frameLeanGitHub(),
        ],
        httpClient: MockClient((request) async {
          if (request.url.host == 'gitee.com') {
            return _jsonResponse(<Object?>[]);
          }

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
          isA<AppUpdateException>()
              .having(
                (error) => error.technicalDetail,
                'technical detail',
                contains('Gitee: 没有发布版本'),
              )
              .having(
                (error) => error.technicalDetail,
                'technical detail',
                contains('GitHub: TLS 握手失败'),
              )
              .having(
                (error) => error.userMessage,
                'user message',
                '暂时无法检查更新，请稍后重试',
              ),
        ),
      );
    });

    test('reports a clear error when every source fails', () async {
      final checker = HostedReleaseUpdateChecker(
        sources: [
          HostedReleaseUpdateSource.frameLeanGitee(),
          HostedReleaseUpdateSource.frameLeanGitHub(),
        ],
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
          isA<AppUpdateException>().having(
            (error) => error.technicalDetail,
            'technical detail',
            contains('Gitee: HTTP 500；GitHub: HTTP 500'),
          ),
        ),
      );
    });
  });
}

Uri _githubTag(String tagName) {
  return Uri.parse(
    'https://github.com/zhouycheng/FrameLean/releases/tag/$tagName',
  );
}

Uri _giteeTag(String tagName) {
  return Uri.parse(
    'https://gitee.com/zhouycheng/FrameLean/releases/tag/$tagName',
  );
}

http.Response _jsonResponse(Object? json) {
  return http.Response.bytes(utf8.encode(jsonEncode(json)), 200);
}

Map<String, Object?> _githubReleaseJson() {
  return {
    'tag_name': 'v1.1.6',
    'name': 'FrameLean v1.1.6',
    'body': 'GitHub 更新说明',
    'html_url': 'https://github.com/zhouycheng/FrameLean/releases/tag/v1.1.6',
    'assets': [
      {
        'name': 'FrameLean-v1.1.6.dmg',
        'browser_download_url':
            'https://github.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg',
        'size': 123,
      },
    ],
  };
}

Map<String, Object?> _giteeReleaseJson() {
  return {
    'tag_name': 'v1.1.6',
    'name': 'FrameLean v1.1.6',
    'description': 'Gitee 更新说明',
    'attach_files': [
      {
        'name': 'FrameLean-v1.1.6.dmg',
        'download_url':
            'https://gitee.com/zhouycheng/FrameLean/releases/download/v1.1.6/FrameLean-v1.1.6.dmg',
        'size': 456,
      },
    ],
  };
}
