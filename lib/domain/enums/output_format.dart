/// 当前任务支持的文件输出格式
enum OutputFormat {
  mp4,
  mov,
  mkv;

  String get label {
    switch (this) {
      case OutputFormat.mp4:
        return "MP4";
      case OutputFormat.mov:
        return "MOV";
      case OutputFormat.mkv:
        return "MKV";
    }
  }
}
