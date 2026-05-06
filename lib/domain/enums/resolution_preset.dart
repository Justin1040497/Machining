/// 当前任务支持的输出分辨率预设
enum ResolutionPreset {
  original,
  p2160,
  p1080,
  p720,
  p480;

  String get label {
    switch (this) {
      case ResolutionPreset.original:
        return "保持原始";
      case ResolutionPreset.p2160:
        return "3840x2160";
      case ResolutionPreset.p1080:
        return "1920x1080";
      case ResolutionPreset.p720:
        return "1280x720";
      case ResolutionPreset.p480:
        return "854x480";
    }
  }
}
