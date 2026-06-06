import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';

/// 通用媒体输出格式。
enum MediaOutputFormat {
  mp4,
  mov,
  mkv,
  jpg,
  png,
  webp,
  bmp,
  tiff,
  gif,
  mp3,
  m4a,
  aac,
  wav,
  flac,
  aiff,
  wma,
  opus,
  oggOpus;

  static MediaOutputFormat fromVideoOutputFormat(OutputFormat format) {
    return switch (format) {
      OutputFormat.mp4 => MediaOutputFormat.mp4,
      OutputFormat.mov => MediaOutputFormat.mov,
      OutputFormat.mkv => MediaOutputFormat.mkv,
    };
  }

  OutputFormat toVideoOutputFormat() {
    return switch (this) {
      MediaOutputFormat.mp4 => OutputFormat.mp4,
      MediaOutputFormat.mov => OutputFormat.mov,
      MediaOutputFormat.mkv => OutputFormat.mkv,
      _ => throw StateError('不是视频输出格式: $name'),
    };
  }

  static List<MediaOutputFormat> formatsFor(MediaKind mediaKind) {
    return switch (mediaKind) {
      MediaKind.video => const [
        MediaOutputFormat.mp4,
        MediaOutputFormat.mov,
        MediaOutputFormat.mkv,
      ],
      MediaKind.image => const [
        MediaOutputFormat.jpg,
        MediaOutputFormat.png,
        MediaOutputFormat.webp,
        MediaOutputFormat.bmp,
        MediaOutputFormat.tiff,
        MediaOutputFormat.gif,
      ],
      MediaKind.audio => const [
        MediaOutputFormat.mp3,
        MediaOutputFormat.m4a,
        MediaOutputFormat.aac,
        MediaOutputFormat.wav,
        MediaOutputFormat.flac,
        MediaOutputFormat.aiff,
        MediaOutputFormat.wma,
        MediaOutputFormat.opus,
        MediaOutputFormat.oggOpus,
      ],
    };
  }
}
