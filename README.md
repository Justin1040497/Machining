# Machining

[![Platform](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-000000)](#安装)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)](#项目架构)
[![FFmpeg](https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808)](#内置-ffmpeg)
[![Encoder](https://img.shields.io/badge/encoder-libx264-444444)](#内置-ffmpeg)
[![Processing](https://img.shields.io/badge/processing-local%20only-2E7D32)](#功能)
[![Runtime License](https://img.shields.io/badge/runtime%20license-GPLv3%2B-C62828)](#许可)

Machining 是一个本地视频压缩桌面应用，基于 Flutter Desktop 和 FFmpeg 构建。现在已经具备了自定义参数压缩视频的功能，在后续，会添加其他文件压缩、格式转换等更多的文件处理的功能，为了秉持操作简单、高质量快速度的产品理念，后续的版本中会逐渐封装各种参数预设，但同样会保留自定义的操作。

Machining 的发布包包含 FFmpeg / FFprobe 运行时。当前内置运行时基于 FFmpeg 7.1.1 和 x264 构建，并启用了 GPL/libx264 相关能力；包含该运行时的分发包需要遵守 GPLv3-or-later 许可要求。FFmpeg 和 x264 归各自原项目维护，Machining 仅调用并随应用分发相应运行时。详细说明见 `docs/` 中的 FFmpeg 许可与分发文档。

## 功能

- 拖拽或选择导入本地视频
- 自动分析视频时长、编码、码率和分辨率
- 生成压缩前后预览帧
- 调整输出格式、编码、分辨率、压缩质量和输出文件名
- 执行视频压缩和格式转换
- 管理任务队列，支持暂停、继续、删除和重命名
- 压缩完成后显示输出路径，并可在 Finder 中打开
- 内置 macOS arm64 FFmpeg / FFprobe，不要求用户安装 Homebrew

## 使用

1. 打开 Machining。
2. 把视频文件拖进窗口，或通过导入按钮选择视频。
3. 选择任务后查看视频信息和预览。
4. 按需要调整输出格式、编码、分辨率、质量和文件名。
5. 点击开始处理。
6. 任务完成后在弹窗中打开输出位置。

如果任务失败，可以在任务列表中查看状态，并根据提示重新处理。

## 安装

目前项目主要面向 macOS Apple Silicon。构建产物是 macOS `.app`：

```text
build/macos/Build/Products/Release/machining.app
```

如果你拿到的是已经构建好的 app，可以直接打开使用。若 macOS 阻止打开，需要根据实际签名和分发方式处理安全设置。

## 开发环境

需要：

- macOS Apple Silicon
- Flutter / Dart
- Xcode Command Line Tools
- Homebrew
- `nasm`
- `pkg-config`

安装 FFmpeg 构建依赖：

```bash
brew install nasm pkg-config
```

安装 Flutter 依赖：

```bash
flutter pub get
```

运行开发版：

```bash
flutter run -d macos
```

## 构建

Debug 构建：

```bash
flutter build macos --debug
```

Release 构建：

```bash
flutter build macos --release
```

Release app 位置：

```text
build/macos/Build/Products/Release/machining.app
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
machining.app/Contents/Resources/ffmpeg/
```

验证 app 实际使用的 FFmpeg：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```

如果输出路径指向 `machining.app/Contents/Resources/ffmpeg/ffmpeg`，说明内置 FFmpeg 已生效。

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

项目文档在 `docs/`，包括产品说明、需求说明、产品设计、技术设计、FFmpeg 许可与分发、路线图、开发计划、数据模型、测试计划和压缩基准计划。

历史开发记录在 `docs/logs/`。

## 许可

项目内置 FFmpeg + x264 构建路线，分发时需要遵守相应的 GPL 许可要求。详细说明见 `docs/` 中的 FFmpeg 许可与分发文档。
