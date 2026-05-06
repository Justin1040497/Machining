/// 媒体文件类型
enum MediaKind {
  video,
  image,
  audio;

  String get label {
    switch (this) {
      case MediaKind.video:
        return '视频';
      case MediaKind.image:
        return '图片';
      case MediaKind.audio:
        return '音频';
    }
  }
}
