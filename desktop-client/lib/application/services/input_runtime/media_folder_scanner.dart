class MediaFolderScanIssue {
  const MediaFolderScanIssue({required this.path, required this.reason});

  final String path;
  final String reason;
}

class MediaFolderScanResult {
  const MediaFolderScanResult({
    required this.mediaFilePaths,
    this.issues = const [],
    this.unsupportedFileCount = 0,
  });

  final List<String> mediaFilePaths;
  final List<MediaFolderScanIssue> issues;
  final int unsupportedFileCount;
}

abstract interface class MediaFolderScanner {
  Future<MediaFolderScanResult> scan({
    required String rootDirectory,
    required int maxDepth,
  });
}
