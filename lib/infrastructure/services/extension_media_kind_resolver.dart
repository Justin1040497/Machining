import 'package:machining/application/services/media_kind_resolver.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:path/path.dart' as path;

/// 使用文件扩展名识别媒体类型
class ExtensionMediaKindResolver implements MediaKindResolver {
  static const videoExtensions = {
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.m4v',
  };

  static const imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  static const audioExtensions = {
    '.mp3',
    '.wav',
    '.aac',
    '.flac',
    '.m4a',
    '.ogg',
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

    throw StateError('不支持的媒体文件类型: $extension');
  }
}
