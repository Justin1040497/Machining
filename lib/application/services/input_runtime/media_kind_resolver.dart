import 'package:framelean/domain/enums/media_kind.dart';

/// 根据文件路径识别媒体类型
abstract class MediaKindResolver {
  /// 识别媒体类型，如果不是支持的媒体文件就抛出异常
  MediaKind resolve(String inputPath);
}
