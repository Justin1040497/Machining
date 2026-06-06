# 媒体输出编码器能力检查

## 背景

音频任务输出 MP3 时，命令规划固定生成 `-c:a libmp3lame`。如果应用解析到的 FFmpeg 运行时没有内置 `libmp3lame`，任务会启动 FFmpeg 后失败，日志只显示 `Unknown encoder 'libmp3lame'` 和 `Encoder not found`。

图片任务输出 WebP 时也依赖 `libwebp`。这类问题本质上是用户可选输出格式和内置 FFmpeg 编码器能力不一致。

## 修复

- `FfmpegEncoderCapabilities` 解析输出格式相关编码器，包括 `libmp3lame`、`libwebp`、`libopus`、`aac`、PCM、FLAC 和 WMA。
- `DefaultFfmpegCommandBuilder` 在构造图片和音频命令时先检查目标格式对应编码器是否可用。
- 如果 MP3 所需的 `libmp3lame` 不存在，任务在命令构造阶段失败，并提示用户指定带该编码器的 FFmpeg 或改选其他音频输出格式。
- 如果 WebP 所需的 `libwebp` 不存在，任务在命令构造阶段失败，并提示用户指定带该编码器的 FFmpeg 或改选其他图片输出格式。
- Opus 和 Ogg Opus 输出统一使用 `libopus`，缺失时走相同的命令构造失败路径。

## 验证

```bash
flutter test test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart
```
