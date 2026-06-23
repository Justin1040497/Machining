import 'dart:io';

import 'package:framelean/app/library.dart';
import 'package:framelean/application/library.dart';
import 'package:path/path.dart' as p;

class LocalAppCacheCleaner implements AppCacheCleaner {
  LocalAppCacheCleaner({
    Directory? tempRoot,
    List<String>? cacheDirectoryNames,
    Future<Directory> Function()? supportDirectoryProvider,
    Future<List<String>> Function()? excludeFilePathsProvider,
  }) : _tempRoot =
            tempRoot ??
            Directory(p.join(Directory.systemTemp.path, tempDirPrefix)),
      _cacheDirectoryNames = cacheDirectoryNames ?? _defaultCacheDirectoryNames,
      _supportDirectoryProvider = supportDirectoryProvider,
      _excludeFilePathsProvider = excludeFilePathsProvider;

  static const _defaultCacheDirectoryNames = <String>[
    'ffmpeg-logs',
    'previews',
    'thumbnails',
    'audio-adapters',
  ];

  final Directory _tempRoot;
  final List<String> _cacheDirectoryNames;
  final Future<Directory> Function()? _supportDirectoryProvider;
  final Future<List<String>> Function()? _excludeFilePathsProvider;

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

    final additional = await _resolvedAdditionalTargets();
    final excludes = await _resolvedExcludePaths();
    for (final target in additional) {
      if (!await target.exists()) {
        missingTargetPaths.add(target.path);
        continue;
      }

      final stats = await _collectStatsExcluding(target, excludes);
      if (stats.fileCount == 0 && stats.directoryCount <= 1) {
        continue;
      }
      targetPaths.add(target.path);
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

    final additional = await _resolvedAdditionalTargets();
    final excludes = await _resolvedExcludePaths();
    for (final target in additional) {
      if (!await target.exists()) {
        continue;
      }

      try {
        final result = await _clearDirectoryContentsExcluding(
          target,
          excludes,
        );
        deletedFileCount += result.deletedFileCount;
        deletedDirectoryCount += result.deletedDirectoryCount;
        releasedBytes += result.releasedBytes;
        for (final skipped in result.skippedItems) {
          skippedItems.add(skipped);
        }
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

  Future<List<Directory>> _resolvedAdditionalTargets() async {
    final provider = _supportDirectoryProvider;
    if (provider == null) {
      return const [];
    }
    final supportDir = await provider();
    return [Directory(p.join(supportDir.path, 'updates'))];
  }

  Future<Set<String>> _resolvedExcludePaths() async {
    final provider = _excludeFilePathsProvider;
    if (provider == null) {
      return const {};
    }
    final paths = await provider();
    return paths
        .where((path) => path.isNotEmpty)
        .map((path) => p.normalize(p.absolute(path)))
        .toSet();
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

  Future<_DirectoryStats> _collectStatsExcluding(
    Directory directory,
    Set<String> excludePaths,
  ) async {
    var fileCount = 0;
    var directoryCount = 1;
    var totalBytes = 0;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final entityPath = p.normalize(p.absolute(entity.path));
      if (excludePaths.contains(entityPath)) {
        continue;
      }
      final stat = await entity.stat();
      if (entity is File) {
        fileCount += 1;
        totalBytes += stat.size;
      } else if (entity is Directory) {
        // Count the directory but skip its contents if parent of excluded
        directoryCount += 1;
      }
    }

    return _DirectoryStats(
      fileCount: fileCount,
      directoryCount: directoryCount,
      totalBytes: totalBytes,
    );
  }

  Future<_ClearDirectoryResult> _clearDirectoryContentsExcluding(
    Directory directory,
    Set<String> excludePaths,
  ) async {
    var deletedFileCount = 0;
    var deletedDirectoryCount = 0;
    var releasedBytes = 0;
    final skippedItems = <AppCacheCleanupSkippedItem>[];

    // List top-level entries only; delete each non-excluded item.
    await for (final entity in directory.list(followLinks: false)) {
      final entityPath = p.normalize(p.absolute(entity.path));
      if (excludePaths.contains(entityPath)) {
        continue;
      }
      try {
        if (entity is File) {
          final len = await entity.length();
          await entity.delete();
          deletedFileCount += 1;
          releasedBytes += len;
        } else if (entity is Directory) {
          final stats = await _collectStats(entity);
          await entity.delete(recursive: true);
          deletedFileCount += stats.fileCount;
          deletedDirectoryCount += stats.directoryCount;
          releasedBytes += stats.totalBytes;
        }
      } on Object catch (error) {
        skippedItems.add(
          AppCacheCleanupSkippedItem(
            path: entity.path,
            reason: error.toString(),
          ),
        );
      }
    }

    // Also remove empty version/platform subdirectories that were left behind.
    // The updates/ tree looks like: updates/<version>/<platform>/setup.exe
    // After deleting the files, empty directories can be cleaned up.
    try {
      await _deleteEmptySubdirectories(directory, excludePaths);
    } on Object {
      // best effort
    }

    return _ClearDirectoryResult(
      deletedFileCount: deletedFileCount,
      deletedDirectoryCount: deletedDirectoryCount,
      releasedBytes: releasedBytes,
      skippedItems: skippedItems,
    );
  }

  Future<void> _deleteEmptySubdirectories(
    Directory directory,
    Set<String> excludePaths,
  ) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final entityPath = p.normalize(p.absolute(entity.path));
      if (excludePaths.any((excluded) => p.isWithin(entityPath, excluded))) {
        continue;
      }
      if (await _isEmptyDirectory(entity)) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<bool> _isEmptyDirectory(Directory directory) async {
    try {
      return await directory.list().isEmpty;
    } on Object {
      return false;
    }
  }
}

class _ClearDirectoryResult {
  const _ClearDirectoryResult({
    required this.deletedFileCount,
    required this.deletedDirectoryCount,
    required this.releasedBytes,
    required this.skippedItems,
  });

  final int deletedFileCount;
  final int deletedDirectoryCount;
  final int releasedBytes;
  final List<AppCacheCleanupSkippedItem> skippedItems;
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
