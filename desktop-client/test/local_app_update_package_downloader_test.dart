import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_package_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'framelean-update-downloader-',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('appends only a matching partial response', () async {
    final file = await _partialFile(supportDirectory, [1, 2, 3]);
    final server = await _serve((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=3-');
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 3-5/6')
        ..add([4, 5, 6]);
    });
    addTearDown(() => server.close(force: true));

    await _download(supportDirectory, server, [1, 2, 3, 4, 5, 6]);

    expect(await file.readAsBytes(), [1, 2, 3, 4, 5, 6]);
  });

  test('overwrites a partial file when the server ignores Range', () async {
    final file = await _partialFile(supportDirectory, [1, 2, 3]);
    final bytes = [1, 2, 3, 4, 5, 6];
    final server = await _serve((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=3-');
      request.response
        ..statusCode = HttpStatus.ok
        ..add(bytes);
    });
    addTearDown(() => server.close(force: true));

    await _download(supportDirectory, server, bytes);

    expect(await file.readAsBytes(), bytes);
  });

  test('deletes a partial file when Content-Range is invalid', () async {
    final file = await _partialFile(supportDirectory, [1, 2, 3]);
    final server = await _serve((request) async {
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-5/6')
        ..add([4, 5, 6]);
    });
    addTearDown(() => server.close(force: true));

    await expectLater(
      _download(supportDirectory, server, [1, 2, 3, 4, 5, 6]),
      throwsA(isA<StateError>()),
    );

    expect(await file.exists(), isFalse);
  });

  test('deletes an oversized response', () async {
    final file = _packageFile(supportDirectory);
    final server = await _serve((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..add([1, 2, 3, 4, 5, 6, 7]);
    });
    addTearDown(() => server.close(force: true));

    await expectLater(
      _download(supportDirectory, server, [1, 2, 3, 4, 5, 6]),
      throwsA(isA<StateError>()),
    );

    expect(await file.exists(), isFalse);
  });

  test('stores macOS DMG in the selected download directory', () async {
    final downloadsDirectory = Directory(
      p.join(supportDirectory.path, 'Downloads'),
    );
    final bytes = [1, 2, 3, 4, 5, 6];
    final server = await _serve((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..add(bytes);
    });
    addTearDown(() => server.close(force: true));

    final result = await _download(
      supportDirectory,
      server,
      bytes,
      platform: 'macos-universal2',
      fileName: 'FrameLean-v1.2.3.dmg',
      downloadDirectoryProvider: ({required version, required platform}) async {
        return downloadsDirectory;
      },
    );

    expect(
      result.filePath,
      p.join(downloadsDirectory.path, 'FrameLean-v1.2.3.dmg'),
    );
    expect(await File(result.filePath).readAsBytes(), bytes);
    expect(
      await Directory(
        p.join(supportDirectory.path, 'updates', '1.2.3', 'macos-universal2'),
      ).exists(),
      isFalse,
    );
  });

  test('deletes a corrupt package so the next download can succeed', () async {
    final expected = [1, 2, 3, 4, 5, 6];
    var requests = 0;
    final server = await _serve((request) async {
      requests += 1;
      request.response
        ..statusCode = HttpStatus.ok
        ..add(requests == 1 ? [6, 5, 4, 3, 2, 1] : expected);
    });
    addTearDown(() => server.close(force: true));

    await expectLater(
      _download(supportDirectory, server, expected),
      throwsA(isA<StateError>()),
    );
    expect(await _packageFile(supportDirectory).exists(), isFalse);

    await _download(supportDirectory, server, expected);
    expect(await _packageFile(supportDirectory).readAsBytes(), expected);
    expect(requests, 2);
  });
}

Future<HttpServer> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } finally {
      await request.response.close();
    }
  });
  return server;
}

Future<AppUpdateDownloadResult> _download(
  Directory supportDirectory,
  HttpServer server,
  List<int> expected, {
  String platform = 'windows-installer',
  String fileName = 'FrameLean-setup.exe',
  AppUpdateDownloadDirectoryProvider? downloadDirectoryProvider,
}) async {
  final downloader = LocalAppUpdatePackageDownloader(
    supportDirectoryProvider: () async => supportDirectory,
    downloadDirectoryProvider: downloadDirectoryProvider,
  );
  return downloader.download(
    ticket: AppUpdateDownloadTicket(
      downloadUrl: Uri.parse('http://127.0.0.1:${server.port}/update'),
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      package: AppUpdatePackageInfo(
        fileName: fileName,
        sizeBytes: expected.length,
        sha256: sha256.convert(expected).toString(),
      ),
    ),
    version: '1.2.3',
    platform: platform,
    cancellationToken: AppUpdateDownloadCancellationToken(),
    onProgress: (_, _) {},
  );
}

Future<File> _partialFile(Directory supportDirectory, List<int> bytes) async {
  final file = _packageFile(supportDirectory);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}

File _packageFile(Directory supportDirectory) => File(
  p.join(
    supportDirectory.path,
    'updates',
    '1.2.3',
    'windows-installer',
    'FrameLean-setup.exe',
  ),
);
