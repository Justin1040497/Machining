abstract interface class AppCacheCleaner {
  Future<AppCacheCleanupPreview> preview();

  Future<AppCacheCleanupResult> clear();
}

class AppCacheCleanupPreview {
  const AppCacheCleanupPreview({
    required this.fileCount,
    required this.directoryCount,
    required this.totalBytes,
    required this.targetPaths,
    required this.missingTargetPaths,
  });

  final int fileCount;
  final int directoryCount;
  final int totalBytes;
  final List<String> targetPaths;
  final List<String> missingTargetPaths;

  bool get isEmpty => fileCount == 0 && directoryCount == 0;
}

class AppCacheCleanupResult {
  const AppCacheCleanupResult({
    required this.deletedFileCount,
    required this.deletedDirectoryCount,
    required this.releasedBytes,
    required this.skippedItems,
  });

  final int deletedFileCount;
  final int deletedDirectoryCount;
  final int releasedBytes;
  final List<AppCacheCleanupSkippedItem> skippedItems;

  bool get hasSkippedItems => skippedItems.isNotEmpty;
}

class AppCacheCleanupSkippedItem {
  const AppCacheCleanupSkippedItem({required this.path, required this.reason});

  final String path;
  final String reason;
}
