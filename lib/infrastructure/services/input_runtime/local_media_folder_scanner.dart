import 'dart:io';

import 'package:framelean/application/library.dart';

class LocalMediaFolderScanner implements MediaFolderScanner {
  const LocalMediaFolderScanner({required this.mediaKindResolver});

  final MediaKindResolver mediaKindResolver;

  @override
  Future<MediaFolderScanResult> scan({
    required String rootDirectory,
    required int maxDepth,
  }) async {
    final mediaFilePaths = <String>[];
    final issues = <MediaFolderScanIssue>[];
    var unsupportedFileCount = 0;
    final normalizedDepth = maxDepth < 0 ? 0 : maxDepth;

    Future<void> visitDirectory(String directoryPath, int depth) async {
      final directory = Directory(directoryPath);
      List<FileSystemEntity> children;
      try {
        children = await directory.list(followLinks: false).toList();
      } on Object catch (error) {
        issues.add(
          MediaFolderScanIssue(path: directoryPath, reason: error.toString()),
        );
        return;
      }

      children.sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        final type = await FileSystemEntity.type(
          child.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file) {
          try {
            mediaKindResolver.resolve(child.path);
            mediaFilePaths.add(child.path);
          } on StateError {
            unsupportedFileCount += 1;
          } on Object catch (error) {
            issues.add(
              MediaFolderScanIssue(path: child.path, reason: error.toString()),
            );
          }
          continue;
        }

        if (type == FileSystemEntityType.directory && depth < normalizedDepth) {
          await visitDirectory(child.path, depth + 1);
          continue;
        }

        if (type == FileSystemEntityType.notFound) {
          issues.add(
            MediaFolderScanIssue(path: child.path, reason: '文件或文件夹不存在'),
          );
        }
      }
    }

    final rootType = await FileSystemEntity.type(
      rootDirectory,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      return MediaFolderScanResult(
        mediaFilePaths: const [],
        issues: [MediaFolderScanIssue(path: rootDirectory, reason: '不是可导入文件夹')],
      );
    }

    await visitDirectory(rootDirectory, 0);
    return MediaFolderScanResult(
      mediaFilePaths: mediaFilePaths,
      issues: issues,
      unsupportedFileCount: unsupportedFileCount,
    );
  }
}
