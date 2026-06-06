import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:path/path.dart' as path;

abstract final class WorkbenchFilePicker {
  static Future<List<XFile>> pickMediaFiles() async {
    try {
      return await openFiles(
        acceptedTypeGroups: WorkbenchConstants.mediaTypeGroups,
      );
    } on ArgumentError {
      return openFiles();
    } on UnimplementedError {
      return openFiles();
    }
  }

  static Future<XFile?> pickMediaFile() async {
    try {
      return await openFile(
        acceptedTypeGroups: WorkbenchConstants.mediaTypeGroups,
      );
    } on ArgumentError {
      return openFile();
    } on UnimplementedError {
      return openFile();
    }
  }

  static Future<List<XFile>> pickVideoFiles() async {
    return pickMediaFiles();
  }

  static Future<XFile?> pickVideoFile() async {
    return pickMediaFile();
  }

  static Future<String?> pickOutputDirectory() {
    return getDirectoryPath(confirmButtonText: '选择导出文件夹');
  }

  static Future<String?> pickExecutablePath() async {
    final file = await openFile();
    return file?.path;
  }

  static String get defaultExportPath {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return Directory.current.path;
    }

    return path.join(home, 'Desktop');
  }
}
