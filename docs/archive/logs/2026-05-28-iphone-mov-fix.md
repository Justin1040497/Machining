# iPhone MOV 执行失败与空日志修复

**日期**: 2026-05-28  
**问题**: iPhone 拍摄的 `.MOV` 文件点击开始后进入失败状态，失败后打开日志窗口为空。

## 现象

- 失败任务只显示失败状态，用户不能从日志窗口看到 FFmpeg 的完整 stderr。
- 真实 FFmpeg 日志中可以看到 iPhone MOV 源包含普通 AAC 音频流，以及 Apple Positional Audio / APAC 音频流。
- 失败片段类似：

```text
[aist#0:2/none] Decoding requested, but no decoder found for: none
Error opening output files: Invalid argument
```

## 根因

### 1. 执行日志被任务状态保存覆盖

新增的日志收集逻辑把 `MediaTask.executionLog` 写入 SQLite。随后队列执行器完成任务收尾时，又用旧的 `MediaTask` 对象调用 `markFailed` / `markCompleted` 并保存，导致刚写入的日志字段被旧对象覆盖为空。

这类执行日志也不适合进入任务实体：FFmpeg stderr 可能很长，生命周期接近临时诊断文件，而不是任务业务状态。

### 2. `-map 0:a?` 映射了不可转码的 APAC 音频流

之前命令使用：

```text
-map 0:v:0 -map 0:a?
```

这会把输入中的所有音频流都映射到输出。iPhone MOV 可能包含普通 `aac` 音频流和 Apple Positional Audio / APAC 音频流；APAC 在 FFmpeg 里表现为 `codec_name=none`，常规转码不能解码。只要它被映射，FFmpeg 就会尝试为该音频输出建立解码链，最终失败。

之前记录中把 `-map_metadata 0` / `0:g` 当作主因是不准确的。当前错误的直接触发点是音频流映射，`mebx` 等数据流不是这次日志里的失败流。

### 3. Apple HEVC 别名和高风险硬件路径

iPhone MOV 的 HEVC 源常见 `codec_name` 为 `hvc1` / `hev1`。如果只识别 `hevc` / `h265`，在“保留源编码”或估算逻辑中会走错分支。

另一个风险是 Apple HDR / Dolby Vision / HLG / 10-bit MOV 使用 VideoToolbox + `scale_vt` + `format=yuv420p` 的组合，在真实样本上没有稳定通过短样本验证。相比“硬件优先”，对这类源短期优先保证成功率。

## 修复

### 日志

- 移除 `MediaTask.executionLog` 和对应 SQLite 字段。
- 新增 `ExecutionLogStore`，从系统临时目录 `framelean/ffmpeg-logs` 读取任务最新 `.log` 文件。
- `LocalFfmpegProcessStarter` 在进程启动前写入命令头，即使 `Process.start` 失败也有诊断入口。
- `LocalFfmpegProcessObserver` 继续把 stderr 全量写入日志文件，任务错误信息只保留尾部摘要。
- `DefaultFfmpegTaskQueueRunner` 在启动失败、执行失败、取消和完成时向日志文件追加诊断尾部。
- `TaskLogDialog` 改为订阅文件日志；如果没有日志但任务失败，展示任务错误信息，避免空白。

### iPhone MOV / FFmpeg 命令

- FFprobe 分析增加 `stream=index`，并保存可转码主音频流 `audioStreamIndex`。
- `FfprobeMediaAnalyzer` 忽略 `none`、`apac` 等不可常规转码音频流。
- FFmpeg 输出从 `-map 0:a?` 改为优先 `-map 0:<audioStreamIndex>?`，旧数据没有索引但音频编码可用时才降级到 `-map 0:a:0?`。
- 保留 `-map_metadata 0:g` 和 `-map_chapters 0`，但它们不是本次 APAC 失败的核心修复。
- 视频编码识别统一到 `MediaCodecNormalizer`，支持 `h264` / `avc1` 和 `hevc` / `h265` / `hvc1` / `hev1`。
- 自动编码后端遇到 Apple HDR / HVC1 / 10-bit MOV 且软件编码可用时，降级到 `libx264` 或 `libx265`；显式选择 VideoToolbox 时继续尊重用户配置。
- 音频编码默认使用 FFmpeg 原生 `aac`，不再自动优先 `aac_at`。

## 外部参考

- FFmpeg 官方文档中 `-map` 是显式输出流选择选项；因此要避免把不可转码流纳入输出，关键是精确映射需要的输入流。
- FFmpeg 官方文档中 `-map_metadata` 是元数据映射选项，和输出流选择不是同一件事。
- FFmpeg 帮助信息中 `-dn` 用于禁用 data streams；本次命令已经通过显式视频/音频 `-map` 不选择 data streams。

## 验证

- `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`
- `flutter analyze`
- `flutter test`
- `flutter test test/ffmpeg_command_builder_test.dart test/ffprobe_media_analyzer_test.dart test/ffmpeg_task_queue_runner_test.dart test/ffmpeg_process_observer_test.dart test/widget_test.dart`

## 后续

- 中期可以加入 1-2 秒 VideoToolbox smoke test：高风险源先用实际命令片段验证硬件路径，失败后自动回退软件编码。
- 如果未来要保留空间音频，需要单独设计 APAC 复制/转码策略；当前压缩路径优先保证普通视频输出成功。
