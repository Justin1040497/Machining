# 2026-05-27 FFmpeg 参数优化记录

## 背景

实际交互测试通过后，部分压缩结果出现轻微变色、局部发紫或变暗。代码检查发现命令构造只固定输出 `-pix_fmt yuv420p`，没有保存和使用 FFprobe 可提供的色彩、帧率、像素格式、声道和采样率信息。

## 原因

- `FfprobeMediaAnalyzer` 只读取基础编码、分辨率、码率和音频字段，缺少色彩、位深、帧率、宽高比、旋转和声道布局。
- `FfmpegVideoArgumentBuilder` 使用裸 `scale=-2:<height>`，未显式处理色彩范围 / 矩阵、SAR、避免上采样和 HDR 转 SDR。
- 音频输出固定为 `-c:a aac -b:a <bitrate>`，没有使用已分析到的声道数和采样率，也没有利用 macOS 可用的 `aac_at`。
- 命令没有显式 `-map`，多音轨或元数据保留依赖 FFmpeg 默认流选择。

## 处理

- 扩展 `MediaAnalysisResult`、FFprobe 解析、Drift 表字段和仓储映射，持久化更多媒体分析信息。
- 输出命令新增显式 `-map 0:v:0 -map 0:a? -map_metadata 0 -map_chapters 0`。
- SDR 输出统一使用 Lanczos 缩放、`format=yuv420p`、`setsar=1` 和 BT.709 / limited range 色彩标签。
- 分辨率预设使用 `min(target, ih)`，避免把低分辨率源视频向上放大。
- HDR + VideoToolbox 路径使用 `scale_vt` 输出 SDR BT.709。
- 音频按源声道 / 采样率输出，低码率目标转 mono，macOS 检测到 `aac_at` 时优先使用 AudioToolbox AAC。

## 验证

- `flutter test test/ffprobe_media_analyzer_test.dart test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart`
