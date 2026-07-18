import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/services/app_maintenance/local_app_cache_cleaner.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'preview and clear only remove allowed FrameLean temp cache dirs',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'framelean_cache_cleaner_test_',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final previewsDir = Directory(p.join(tempRoot.path, 'previews'));
      final thumbnailsDir = Directory(
        p.join(tempRoot.path, 'thumbnails', 'nested'),
      );
      final unrelatedDir = Directory(p.join(tempRoot.path, 'unrelated'));
      await previewsDir.create(recursive: true);
      await thumbnailsDir.create(recursive: true);
      await unrelatedDir.create(recursive: true);
      await File(
        p.join(previewsDir.path, 'preview.bin'),
      ).writeAsBytes(<int>[1, 2, 3]);
      await File(
        p.join(thumbnailsDir.path, 'thumb.bin'),
      ).writeAsBytes(<int>[4, 5]);
      await File(p.join(unrelatedDir.path, 'keep.bin')).writeAsBytes(<int>[6]);

      final cleaner = LocalAppCacheCleaner(tempRoot: tempRoot);
      final preview = await cleaner.preview();

      expect(preview.fileCount, 2);
      expect(preview.totalBytes, 5);
      expect(preview.targetPaths, contains(p.join(tempRoot.path, 'previews')));
      expect(
        preview.targetPaths,
        contains(p.join(tempRoot.path, 'thumbnails')),
      );
      expect(preview.targetPaths, isNot(contains(unrelatedDir.path)));

      final result = await cleaner.clear();

      expect(result.deletedFileCount, 2);
      expect(result.releasedBytes, 5);
      expect(result.skippedItems, isEmpty);
      expect(await previewsDir.exists(), isFalse);
      expect(
        await Directory(p.join(tempRoot.path, 'thumbnails')).exists(),
        isFalse,
      );
      expect(await unrelatedDir.exists(), isTrue);
      expect(
        await File(p.join(unrelatedDir.path, 'keep.bin')).exists(),
        isTrue,
      );
    },
  );
}
