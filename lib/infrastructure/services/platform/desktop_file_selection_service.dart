import 'dart:io';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:file_selector/file_selector.dart';
import 'package:framelean/application/services/platform/file_selection_service.dart';
import 'package:path/path.dart' as path;

class DesktopFileSelectionService implements FileSelectionService {
  const DesktopFileSelectionService();

  static const videoTypeGroup = XTypeGroup(
    label: '视频文件',
    extensions: [
      'mp4',
      'mov',
      'mkv',
      'm4v',
      'avi',
      'webm',
      'flv',
      'wmv',
      'mpg',
      'mpeg',
      'ts',
      'm2ts',
      'mts',
      '3gp',
      '3g2',
      'vob',
      'ogv',
      'dv',
      'asf',
    ],
    uniformTypeIdentifiers: [
      'public.movie',
      'public.video',
      'public.mpeg-4',
      'com.apple.quicktime-movie',
      'org.matroska.mkv',
    ],
  );

  static const imageTypeGroup = XTypeGroup(
    label: '图片文件',
    extensions: [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'bmp',
      'gif',
      'tif',
      'tiff',
      'heic',
      'heif',
      'avif',
      'ico',
      'tga',
    ],
    uniformTypeIdentifiers: [
      'public.image',
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );

  static const audioTypeGroup = XTypeGroup(
    label: '音频文件',
    extensions: [
      'mp3',
      'wav',
      'aac',
      'flac',
      'm4a',
      'ogg',
      'oga',
      'opus',
      'weba',
      'aiff',
      'aif',
      'aifc',
      'wma',
      'amr',
      'ape',
      'alac',
      'caf',
      'au',
      'wv',
      'tta',
      'ncm',
      'mgg',
      'mgg0',
      'mgg1',
      'mggl',
      'mflac',
      'mflac0',
      'qmcflac',
    ],
    uniformTypeIdentifiers: [
      'public.audio',
      'public.mp3',
      'public.mpeg-4-audio',
      'com.microsoft.waveform-audio',
    ],
  );

  static const mediaTypeGroups = [
    videoTypeGroup,
    imageTypeGroup,
    audioTypeGroup,
  ];

  @override
  Future<List<String>> pickImportPaths() async {
    if (Platform.isMacOS) {
      final paths = await file_picker.FilePicker.pickFileAndDirectoryPaths(
        type: file_picker.FileType.any,
      );
      if (paths != null) {
        return paths.where((path) => path.trim().isNotEmpty).toList();
      }
      return const <String>[];
    }

    return pickMediaFiles();
  }

  @override
  Future<List<String>> pickMediaFiles() async {
    try {
      final files = await openFiles(acceptedTypeGroups: mediaTypeGroups);
      return files.map((file) => file.path).toList();
    } on ArgumentError {
      final files = await openFiles();
      return files.map((file) => file.path).toList();
    } on UnimplementedError {
      final files = await openFiles();
      return files.map((file) => file.path).toList();
    }
  }

  @override
  Future<String?> pickMediaFile() async {
    try {
      return (await openFile(acceptedTypeGroups: mediaTypeGroups))?.path;
    } on ArgumentError {
      return (await openFile())?.path;
    } on UnimplementedError {
      return (await openFile())?.path;
    }
  }

  @override
  Future<List<String>> pickMediaDirectories() async {
    final paths = await getDirectoryPaths(confirmButtonText: '导入文件夹');
    return paths
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<String?> pickMediaDirectory() {
    return getDirectoryPath(confirmButtonText: '导入文件夹');
  }

  @override
  Future<String?> pickOutputDirectory() {
    return getDirectoryPath(confirmButtonText: '选择导出文件夹');
  }

  @override
  Future<String?> pickExecutablePath() async {
    return (await openFile())?.path;
  }

  @override
  String get defaultExportPath {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.trim().isEmpty) {
      return Directory.current.path;
    }

    return path.join(home, 'Desktop');
  }
}
