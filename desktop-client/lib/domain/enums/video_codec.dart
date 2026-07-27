/// 当前视频任务支持的视频编码格式
/// 这里注意"视频格式"和"视频编码格式"不是一个东西 不是说H.264、H.265就等于MP4
/// MP4视频格式里面可以装不同编码格式的视频内容
enum VideoCodec {
  /// 不强制指定目标编码，默认跟随 FLL Snapshot 中的源视频编码。
  source,
  h264,
  hevc,
  vp9,
  av1,
  proRes,
  mpeg4,
  mjpeg,
}
