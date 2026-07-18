import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_media_folder_scanner.dart';
import 'package:path/path.dart' as path;

void main() {
  test('scans media files up to the requested folder depth', () async {
    final root = await Directory.systemTemp.createTemp('framelean_scan_test_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    await File(path.join(root.path, 'root.mp4')).writeAsString('');
    await File(path.join(root.path, 'notes.txt')).writeAsString('');
    final child = await Directory(path.join(root.path, 'child')).create();
    await File(path.join(child.path, 'child.jpg')).writeAsString('');
    final grandchild = await Directory(
      path.join(child.path, 'grandchild'),
    ).create();
    await File(path.join(grandchild.path, 'grandchild.mp3')).writeAsString('');

    final scanner = LocalMediaFolderScanner(
      mediaKindResolver: FileExtensionMediaKindResolver(),
    );

    final depthOne = await scanner.scan(rootDirectory: root.path, maxDepth: 1);
    expect(
      depthOne.mediaFilePaths.map(path.basename),
      containsAll(['root.mp4', 'child.jpg']),
    );
    expect(
      depthOne.mediaFilePaths.map(path.basename),
      isNot(contains('grandchild.mp3')),
    );
    expect(depthOne.unsupportedFileCount, 1);

    final depthTwo = await scanner.scan(rootDirectory: root.path, maxDepth: 2);
    expect(
      depthTwo.mediaFilePaths.map(path.basename),
      contains('grandchild.mp3'),
    );
  });
}
