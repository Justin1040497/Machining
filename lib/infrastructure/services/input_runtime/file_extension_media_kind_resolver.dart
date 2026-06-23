import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

/// 使用文件扩展名识别媒体类型
class FileExtensionMediaKindResolver implements MediaKindResolver {
  static const videoExtensions = {
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.m4v',
    '.flv',
    '.wmv',
    '.mpg',
    '.mpeg',
    '.ts',
    '.m2ts',
    '.mts',
    '.3gp',
    '.3g2',
    '.vob',
    '.ogv',
    '.dv',
    '.asf',
  };

  static const imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.tif',
    '.tiff',
    '.heic',
    '.heif',
    '.avif',
    '.ico',
    '.tga',
  };

  static const audioExtensions = {
    '.mp3',
    '.wav',
    '.aac',
    '.flac',
    '.m4a',
    '.ogg',
    '.oga',
    '.opus',
    '.weba',
    '.aiff',
    '.aif',
    '.aifc',
    '.wma',
    '.amr',
    '.ape',
    '.alac',
    '.caf',
    '.au',
    '.wv',
    '.tta',
  };

  @override
  MediaKind resolve(String inputPath) {
    final extension = path.extension(inputPath).toLowerCase();

    if (videoExtensions.contains(extension)) {
      return MediaKind.video;
    }

    if (imageExtensions.contains(extension)) {
      return MediaKind.image;
    }

    if (audioExtensions.contains(extension)) {
      return MediaKind.audio;
    }

    if (ProprietaryAudioFormat.fromPath(inputPath) != null) {
      return MediaKind.audio;
    }

    throw StateError('不支持的媒体文件类型: $extension');
  }
}
