# Machining

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-000000)](#安装)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)](#项目架构)
[![FFmpeg](https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808)](#内置-ffmpeg)
[![Encoder](https://img.shields.io/badge/encoder-GPU%20accelerated-444444)](#gpu-编码加速)
[![Processing](https://img.shields.io/badge/processing-local%20only-2E7D32)](#功能)
[![Runtime License](https://img.shields.io/badge/runtime%20license-GPLv3%2B-C62828)](#许可)

Machining 是一个本地视频压缩桌面应用，基于 Flutter Desktop 和 FFmpeg 构建。现在已经具备了自定义参数压缩视频的功能，在后续，会添加其他文件压缩、格式转换等更多的文件处理的功能，为了秉持操作简单、高质量快速度的产品理念，后续的版本中会逐渐封装各种参数预设，但同样会保留自定义的操作。

Machining 的发布包包含 FFmpeg / FFprobe 运行时。当前内置运行时基于 FFmpeg 7.1.1 构建，支持 CPU 编码和可用平台的 GPU 硬件编码；包含该运行时的分发包需要遵守对应 FFmpeg 构建的许可要求。FFmpeg、x264 等依赖归各自原项目维护，Machining 仅调用并随应用分发相应运行时。详细说明见 `docs/` 中的 FFmpeg 许可与分发文档。

## 功能

- 拖拽或选择导入本地视频
- 自动分析视频时长、编码、码率和分辨率
- 生成压缩前后预览帧
- 调整输出格式、视频编码、编码器、分辨率、压缩质量和输出文件名
- 支持 macOS 和 Windows 的 GPU 硬件编码加速，自动检测 FFmpeg 可用编码器
- 执行视频压缩和格式转换
- 管理任务队列，支持暂停、继续、删除和重命名
- 压缩完成后显示输出路径，并可在 Finder 中打开
- 内置 macOS arm64 和 Windows x64 FFmpeg / FFprobe，不要求用户手动安装 FFmpeg

## 使用

1. 打开 Machining。
2. 把视频文件拖进窗口，或通过导入按钮选择视频。
3. 选择任务后查看视频信息和预览。
4. 按需要调整输出格式、视频编码、编码器、分辨率、质量和文件名。
5. 点击开始处理。
6. 任务完成后在弹窗中打开输出位置。

如果任务失败，可以在任务列表中查看状态，并根据提示重新处理。

## 安装

目前项目支持 macOS Apple Silicon 和 Windows x64。macOS 构建产物是 `.app`：

```text
build/macos/Build/Products/Release/Machining.app
```

Windows 构建产物位于：

```text
build/windows/x64/runner/Release/
```

如果你拿到的是已经构建好的 app，可以直接打开使用。若 macOS 阻止打开，需要根据实际签名和分发方式处理安全设置。

## 开发环境

需要：

- Flutter / Dart
- macOS Apple Silicon 或 Windows x64
- macOS 开发需要 Xcode Command Line Tools、Homebrew、`nasm`、`pkg-config`
- Windows 开发需要 Visual Studio C++ 桌面构建工具

macOS 安装 FFmpeg 构建依赖：

```bash
brew install nasm pkg-config
```

安装 Flutter 依赖：

```bash
flutter pub get
```

运行 macOS 开发版：

```bash
flutter run -d macos
```

运行 Windows 开发版：

```powershell
flutter run -d windows
```

## 构建

macOS Debug 构建：

```bash
flutter build macos --debug
```

macOS Release 构建：

```bash
flutter build macos --release
```

macOS Release app 位置：

```text
build/macos/Build/Products/Release/Machining.app
```

Windows Release 构建：

```powershell
flutter build windows --release
```

Windows Release 位置：

```text
build/windows/x64/runner/Release/
```

## 内置 FFmpeg

Machining 运行时优先使用应用包内的 FFmpeg / FFprobe。仓库中的放置位置是：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

这些二进制文件不提交到 Git，需要在对应平台本地准备。
`third_party` 目录本身会保留在仓库中，用来放置说明文件和运行时目录结构；只有 `ffmpeg`、`ffprobe`、`ffmpeg.exe`、`ffprobe.exe` 这类平台二进制被 `.gitignore` 排除。

macOS arm64 运行时可以用脚本生成：

```bash
scripts/build_ffmpeg_macos_arm64.sh
```

脚本会构建 FFmpeg 和 x264，并检查：

- 没有 Homebrew 动态库依赖
- `libx264` 编码器可用

macOS 构建时，Xcode 会把二进制复制到：

```text
Machining.app/Contents/Resources/ffmpeg/
```

验证 app 实际使用的 FFmpeg：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```

如果输出路径指向 `Machining.app/Contents/Resources/ffmpeg/ffmpeg`，说明内置 FFmpeg 已生效。

Windows 构建时，CMake 会把：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

复制到：

```text
machining.exe 同级目录/ffmpeg/
```

如果这两个文件不存在，Windows 构建会直接失败，避免生成缺少内置 FFmpeg 的发布包。

## GPU 编码加速

Machining 会在解析 FFmpeg 运行时时执行 `ffmpeg -hide_banner -encoders`，检测当前 FFmpeg 支持哪些硬件编码器。任务配置为“自动选择”时，会优先使用可用 GPU 编码器；如果当前电脑或 FFmpeg 不支持对应编码器，会回退到 CPU 编码。

macOS 支持：

```text
H.264 -> h264_videotoolbox
HEVC  -> hevc_videotoolbox
```

Windows 支持：

```text
NVIDIA -> h264_nvenc / hevc_nvenc
Intel  -> h264_qsv / hevc_qsv
AMD    -> h264_amf / hevc_amf
```

自动选择优先级：

```text
macOS   -> VideoToolbox -> libx264/libx265
Windows -> NVENC -> Quick Sync -> AMF -> libx264/libx265
```

可以在 Windows 上用以下命令确认内置 FFmpeg 是否包含 GPU 编码器：

```powershell
third_party\ffmpeg\windows-x64\ffmpeg.exe -hide_banner -encoders
```

输出中如果包含 `h264_nvenc`、`h264_qsv` 或 `h264_amf`，Machining 就可以在对应硬件可用时使用 GPU 编码。

## 项目架构

项目采用分层结构，让 UI、业务规则、数据存储和 FFmpeg 进程调用分开。

```text
lib/
  app/
    app.dart
    app_router.dart

  domain/
    entities/
    enums/
    value_objects/

  application/
    repositories/
    services/

  infrastructure/
    database/
    providers/
    repositories/
    services/

  features/
    workbench/
      pages/
      providers/
      widgets/
```

各层职责：

- `app`：应用入口、路由和全局配置
- `domain`：任务、设置、枚举和值对象
- `application`：仓储接口、媒体分析、命令构造、队列执行等用例服务
- `infrastructure`：Drift 数据库、FFmpeg/FFprobe、本地文件和进程实现
- `features/workbench`：工作台 UI、任务列表和页面状态协调

核心流程：

```text
导入文件
  -> 创建 MediaTask
  -> FFprobe 分析
  -> 生成预览
  -> 构造 FFmpeg 命令
  -> 队列启动进程
  -> 观测进度和日志
  -> 写回完成或失败状态
```

## 测试

静态分析：

```bash
flutter analyze
```

单元测试：

```bash
flutter test
```

测试覆盖重点：

- 压缩建议策略
- FFmpeg 命令构造
- FFmpeg 队列执行
- 进度观测
- FFprobe 媒体分析
- 预览帧生成

## 文档

项目文档入口在 `docs/README.md`。

常用文档目录：

- `docs/product/`：产品范围、需求、设计和路线图
- `docs/architecture/`：技术设计、技术栈和数据模型
- `docs/features/`：功能版本开发流水线
- `docs/develop/`：发布计划、测试计划和验证说明
- `docs/reference/`：FFmpeg 许可、分发和图表资料
- `docs/archive/`：历史日志和旧计划

## 许可

项目内置 FFmpeg + x264 构建路线，分发时需要遵守相应的 GPL 许可要求。详细说明见 `docs/reference/ffmpeg-license-and-distribution-v1.0.md`。
