import 'dart:io';

import 'package:framelean/app/constants.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:path/path.dart' as p;

class LocalAppCacheCleaner implements AppCacheCleaner {
  LocalAppCacheCleaner({Directory? tempRoot, List<String>? cacheDirectoryNames})
    : _tempRoot =
          tempRoot ?? Directory(p.join(Directory.systemTemp.path, tempDirPrefix)),
      _cacheDirectoryNames = cacheDirectoryNames ?? _defaultCacheDirectoryNames;

  static const _defaultCacheDirectoryNames = <String>[
    'ffmpeg-logs',
    'previews',
    'thumbnails',
    'audio-adapters',
  ];

  final Directory _tempRoot;
  final List<String> _cacheDirectoryNames;

  @override
  Future<AppCacheCleanupPreview> preview() async {
    var fileCount = 0;
    var directoryCount = 0;
    var totalBytes = 0;
    final targetPaths = <String>[];
    final missingTargetPaths = <String>[];

    for (final target in _targetDirectories()) {
      final safe = _isSafeTarget(target);
      final exists = await target.exists();
      if (!safe || !exists) {
        if (!exists) {
          missingTargetPaths.add(target.path);
        }
        continue;
      }

      targetPaths.add(target.path);
      final stats = await _collectStats(target);
      fileCount += stats.fileCount;
      directoryCount += stats.directoryCount;
      totalBytes += stats.totalBytes;
    }

    return AppCacheCleanupPreview(
      fileCount: fileCount,
      directoryCount: directoryCount,
      totalBytes: totalBytes,
      targetPaths: List.unmodifiable(targetPaths),
      missingTargetPaths: List.unmodifiable(missingTargetPaths),
    );
  }

  @override
  Future<AppCacheCleanupResult> clear() async {
    var deletedFileCount = 0;
    var deletedDirectoryCount = 0;
    var releasedBytes = 0;
    final skippedItems = <AppCacheCleanupSkippedItem>[];

    for (final target in _targetDirectories()) {
      if (!_isSafeTarget(target)) {
        skippedItems.add(
          AppCacheCleanupSkippedItem(
            path: target.path,
            reason: '不在 FrameLean 临时缓存允许列表内',
          ),
        );
        continue;
      }

      if (!await target.exists()) {
        continue;
      }

      try {
        final stats = await _collectStats(target);
        await target.delete(recursive: true);
        deletedFileCount += stats.fileCount;
        deletedDirectoryCount += stats.directoryCount;
        releasedBytes += stats.totalBytes;
      } on Object catch (error) {
        skippedItems.add(
          AppCacheCleanupSkippedItem(
            path: target.path,
            reason: error.toString(),
          ),
        );
      }
    }

    return AppCacheCleanupResult(
      deletedFileCount: deletedFileCount,
      deletedDirectoryCount: deletedDirectoryCount,
      releasedBytes: releasedBytes,
      skippedItems: List.unmodifiable(skippedItems),
    );
  }

  Iterable<Directory> _targetDirectories() {
    return _cacheDirectoryNames.map(
      (name) => Directory(p.join(_tempRoot.path, name)),
    );
  }

  bool _isSafeTarget(Directory directory) {
    final rootPath = p.normalize(p.absolute(_tempRoot.path));
    final targetPath = p.normalize(p.absolute(directory.path));

    if (targetPath == rootPath || !p.isWithin(rootPath, targetPath)) {
      return false;
    }

    return _cacheDirectoryNames.contains(p.basename(targetPath));
  }

  Future<_DirectoryStats> _collectStats(Directory directory) async {
    var fileCount = 0;
    var directoryCount = 1;
    var totalBytes = 0;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final stat = await entity.stat();
      if (entity is File) {
        fileCount += 1;
        totalBytes += stat.size;
      } else if (entity is Directory) {
        directoryCount += 1;
      }
    }

    return _DirectoryStats(
      fileCount: fileCount,
      directoryCount: directoryCount,
      totalBytes: totalBytes,
    );
  }
}

class _DirectoryStats {
  const _DirectoryStats({
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int directoryCount;
  final int totalBytes;
}
