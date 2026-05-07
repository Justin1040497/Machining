# 2026-05-07 Windows Runtime Packaging Fixes

## Problem Summary

Windows 端试运行时发现三个问题：

1. 发布产物中没有内置 `ffmpeg.exe` / `ffprobe.exe`。
2. 窗口没有最小尺寸限制，缩小后工作台布局会被压坏。
3. 左侧任务列表读取失败，错误信息显示无法加载 `sqlite3.dll`。

任务列表错误示例：

```text
Invalid argument(s): Couldn't resolve native function 'sqlite3_initialize'
Failed to load dynamic library 'sqlite3.dll'
The specified module could not be found. (error code: 126)
```

## Root Cause

### Windows FFmpeg Runtime

macOS 已经有 Xcode build phase 负责复制内置 FFmpeg，但 Windows CMake 之前没有对应逻辑。

应用的 Dart 运行时查找器已经支持：

```text
<exe directory>/ffmpeg/ffmpeg.exe
<exe directory>/ffmpeg/ffprobe.exe
```

但构建产物中没有把 `third_party/ffmpeg/windows-x64` 下的二进制复制进去。

### Window Minimum Size

Windows Runner 使用 Flutter 默认窗口模板，没有处理 `WM_GETMINMAXINFO`，因此用户可以把窗口缩到小于当前工作台布局可承载的尺寸。

### SQLite On Windows

项目之前使用：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
```

这能避免 macOS 测试阶段从 GitHub 下载 sqlite3 native asset，但在 Windows 上默认会尝试加载 `sqlite3.dll`。Windows 系统通常自带的是 `winsqlite3.dll`，不是 `sqlite3.dll`，因此数据库初始化失败。

## Fix

### Bundle Windows FFmpeg

在 `windows/CMakeLists.txt` 中增加 Windows FFmpeg 复制规则。

约定本地二进制放置位置：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

构建时复制到：

```text
<machining.exe directory>/ffmpeg/
```

如果缺少这两个文件，Windows 构建直接失败，避免生成没有内置 FFmpeg 的发布包。

### Add Windows Runtime README And Ignore Rules

新增 `third_party/ffmpeg/windows-x64/README.md` 说明 Windows FFmpeg 放置规则。

`.gitignore` 只忽略 Windows FFmpeg 二进制：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

目录和 README 会保留在仓库中。

### Configure SQLite System Library Name

保留系统 SQLite 策略，但为 Windows 指定库名：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
      name: sqlite3
      name_windows: winsqlite3
```

这样：

- macOS / Linux 继续使用 `sqlite3` 系统库。
- Windows 使用系统自带的 `winsqlite3.dll`。
- macOS 测试仍避免下载 GitHub sqlite3 native asset。

### Add Windows Minimum Window Size

在 `windows/runner/win32_window.cpp` 中处理 `WM_GETMINMAXINFO`。

最小逻辑尺寸：

```text
1216 x 893
```

在 150% Windows 缩放下约等于：

```text
1824 x 1340 physical pixels
```

该尺寸参考 Windows 端实测截图中的 `1823 x 1339 px`。

默认启动尺寸也调整为：

```text
1216 x 893
```

## Modified Files

- `.gitignore`
- `README.md`
- `pubspec.yaml`
- `windows/CMakeLists.txt`
- `windows/runner/main.cpp`
- `windows/runner/win32_window.cpp`

## Added Files

- `third_party/ffmpeg/windows-x64/README.md`
- `docs/logs/2026-05-07-windows-runtime-packaging-fixes.md`

## Deleted Files

No deleted files.

## Windows Build Notes

Before building on Windows, place the runtime files at:

```text
third_party\ffmpeg\windows-x64\ffmpeg.exe
third_party\ffmpeg\windows-x64\ffprobe.exe
```

Then run:

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

Expected output files:

```text
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe
```

## Validation Method Or Test Result

On macOS development machine:

```text
flutter pub get
flutter analyze
flutter test
```

Results:

```text
flutter pub get: passed
flutter analyze: No issues found
flutter test: 40 tests passed
```

Windows native build still needs to be verified on the Windows machine because macOS cannot run `flutter build windows`.

---

# 2026-05-07 GPU Encoder Acceleration

## Problem Summary

Machining 原先的“自动选择”编码器实际仍然回退到 CPU 编码：

```text
H.264 -> libx264
HEVC  -> libx265
```

这样在 macOS 和 Windows 上即使 FFmpeg 具备硬件编码器，任务也不会自动使用 GPU 加速。

## Goal

在不破坏现有 FFmpeg 队列、预览和命令构造结构的前提下，增加跨平台 GPU 编码加速：

- macOS 支持 VideoToolbox。
- Windows 支持 NVIDIA NVENC、Intel Quick Sync、AMD AMF。
- `auto` 能按平台和 FFmpeg 能力自动选择 GPU 编码器。
- 如果当前 FFmpeg 或硬件不支持 GPU 编码器，自动回退到 `libx264` / `libx265`。

## Fix

### Add Encoder Capability Model

新增 `FfmpegEncoderCapabilities`，集中记录当前 FFmpeg 支持的 encoder 名称和自动选择优先级。

检测命令：

```text
ffmpeg -hide_banner -encoders
```

识别的硬件编码器：

```text
h264_videotoolbox
hevc_videotoolbox
h264_nvenc
hevc_nvenc
h264_qsv
hevc_qsv
h264_amf
hevc_amf
```

### Detect Capabilities In Runtime Resolution

`LocalFfmpegLocator` 在解析到可用 `ffmpeg` 后，读取 `-encoders` 输出并生成能力对象。

自动选择优先级：

```text
macOS   -> VideoToolbox -> libx264/libx265
Windows -> NVENC -> QSV -> AMF -> libx264/libx265
```

### Extend Encoder Backend

`EncoderBackend` 增加：

```text
nvenc
qsv
amf
```

UI 侧新增“编码器”下拉项。用户可以选择：

- 自动选择
- 平台硬件编码器
- 当前目标编码对应的软件编码器

切换 H.264 / HEVC 时，如果当前软件编码器不兼容，会自动回到“自动选择”。

### Update FFmpeg Command Builder

`DefaultFfmpegCommandBuilder` 现在接收 `FfmpegEncoderCapabilities`，并根据目标编码和后端解析实际 FFmpeg encoder。

压缩参数按 encoder 类型分流：

- `libx264` / `libx265`：继续使用 `-preset` + `-crf` 或目标码率。
- VideoToolbox：使用 `-q:v` 或目标码率。
- NVENC：使用 `-preset p5`、`-rc vbr`、`-cq` 或目标码率。
- QSV：使用 `-global_quality` 或目标码率。
- AMF：使用 `-quality balanced`、`-rc cqp` / `vbr_peak`。

### Wire Queue And Preview

正式任务队列和预览片段生成都会传入同一份 runtime encoder capabilities，避免预览和正式导出使用不同的编码路线。

预览 fingerprint 也包含 FFmpeg encoder capability 信息，防止能力变化后复用旧预览。

## Modified Files

- `README.md`
- `lib/application/services/ffmpeg_command_builder.dart`
- `lib/application/services/ffmpeg_locator.dart`
- `lib/application/services/ffmpeg_task_queue_runner.dart`
- `lib/application/services/preview_frame_generator.dart`
- `lib/domain/enums/encoder_backend.dart`
- `lib/features/workbench/pages/workbench_page.dart`
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
- `lib/infrastructure/services/local_ffmpeg_locator.dart`
- `lib/infrastructure/services/local_preview_frame_generator.dart`
- `test/ffmpeg_command_builder_test.dart`
- `test/ffmpeg_task_queue_runner_test.dart`

## Added Files

- `lib/application/services/ffmpeg_encoder_capabilities.dart`

## Validation Method Or Test Result

On macOS development machine:

```text
flutter test test/ffmpeg_command_builder_test.dart test/ffmpeg_task_queue_runner_test.dart test/preview_frame_generator_test.dart
flutter analyze
```

Results:

```text
Selected Flutter tests: passed, 33 tests
flutter analyze: No issues found
```

Also inspected bundled Windows runtime binary strings and found GPU encoder symbols:

```text
h264_nvenc
hevc_nvenc
h264_qsv
hevc_qsv
h264_amf
hevc_amf
```

Final runtime validation still needs to run on Windows with:

```powershell
third_party\ffmpeg\windows-x64\ffmpeg.exe -hide_banner -encoders
```
