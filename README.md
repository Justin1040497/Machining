# Machining

[![Version](https://img.shields.io/badge/version-v1.3.0%2B1-111111)](#当前版本)
[![Platform](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon%20%7C%20Windows%20x64-000000)](#平台范围)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)](#项目结构)
[![FFmpeg](https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808)](#ffmpeg--ffprobe-运行时)
[![Processing](https://img.shields.io/badge/processing-local%20only-2E7D32)](#功能)
[![Runtime License](https://img.shields.io/badge/runtime%20license-GPLv3%2B-C62828)](#许可说明)

Machining 是一个本地桌面视频压缩工具，基于 Flutter Desktop、FFmpeg / FFprobe、Riverpod、Drift 和 SQLite 构建。它把常用的视频分析、预览、压缩、输出格式配置和任务队列能力封装成图形界面，让用户不用手写 FFmpeg 命令，也能在本机处理视频文件。

当前版本聚焦视频压缩工作流：导入本地视频，分析源文件信息，选择智能压缩预设或目标体积，配置编码、分辨率和输出格式，然后在本地执行 FFmpeg。媒体文件不上传到远程服务。

## 当前版本

当前项目版本为：

```text
v1.3.0+1
```

v1.3 的主要内容：

- 智能压缩预设：均衡推荐、微信发送、清晰优先、体积优先。
- 目标体积压缩：根据视频时长和目标大小计算码率，软件编码下支持目标体积两遍压缩。
- 压缩结果预估：展示预计输出大小、目标视频码率和目标音频码率。
- 任务配置弹窗重构：集中配置输出格式、编码、分辨率、压缩模式和输出文件名。
- 主界面模块拆分：顶部栏、底部栏、任务列表、预览区、文件信息、导出路径和视频配置面板独立维护。
- 跨平台打开文件所在位置：macOS Finder、Windows Explorer、Linux 文件管理器。
- 默认编码后端恢复为自动选择，并根据 FFmpeg 能力检测优先使用可用 GPU 编码器。

完整变更记录见 [docs/archive/changelog.md](/Users/leftzhou/工作区/Machining/docs/archive/changelog.md)。

## 平台范围

当前主要支持和验证的平台：

- macOS Apple Silicon
- Windows x64

仓库中保留了 Flutter 默认生成的 Linux、Web 等工程目录，但当前发布和运行时打包说明以 macOS Apple Silicon 和 Windows x64 为准。

## 功能

- 拖拽或选择导入本地视频。
- 支持常见视频输入扩展名：MP4、MOV、MKV、AVI、WEBM、M4V。
- 使用 FFprobe 分析时长、分辨率、视频编码、音频编码、码率和容器信息。
- 生成视频缩略图和压缩前后预览素材。
- 配置输出格式：MP4、MOV、MKV。
- 配置目标视频编码：跟随源文件、H.264、H.265 / HEVC。
- 配置编码后端：自动选择、libx264、libx265、VideoToolbox、NVIDIA NVENC、Intel Quick Sync、AMD AMF。
- 配置输出分辨率：保持原始、2160p、1080p、720p、480p。
- 使用智能压缩、质量优先或目标体积模式。
- 自定义输出目录和输出文件名。
- 串行执行任务队列，支持开始、暂停、继续、取消、删除、重试和重命名。
- 应用重启后从本地 SQLite 恢复任务和设置。
- 源文件丢失或变更后提示重新指定或重新分析。
- 压缩完成后显示输出路径，并打开文件所在位置。
- 内置或自动查找 FFmpeg / FFprobe，并检测当前运行时可用的硬件编码器。

当前版本只支持视频任务。图片、音频和更多文件处理能力可以作为后续版本方向，但不属于 v1.3 已完成范围。

## 怎么用

1. 打开 Machining。
2. 将视频文件拖入窗口，或使用导入按钮选择本地视频。
3. 在任务列表中选择视频，查看源文件信息、缩略图和预览。
4. 打开任务详情设置，选择压缩模式：
   - 智能推荐：选择均衡推荐、微信发送、清晰优先或体积优先。
   - 目标体积：输入希望输出文件接近的大小。
   - 质量优先：通过质量档位控制压缩强度。
5. 按需调整输出格式、视频编码、分辨率、输出目录和输出文件名。
6. 点击开始处理，任务进入本地 FFmpeg 队列。
7. 处理完成后，在完成弹窗或任务信息中打开输出文件所在位置。

如果任务失败，可以查看任务状态和错误提示后重试。若源文件被移动或删除，应用会将任务标记为源文件丢失，需要重新指定文件。

## 开发环境

基础要求：

- Flutter / Dart，当前项目使用 Dart SDK `^3.11.0`。
- macOS 开发需要 Xcode Command Line Tools。
- Windows 开发需要 Visual Studio C++ Desktop Build Tools。
- macOS 构建 FFmpeg 运行时需要 Homebrew、`nasm`、`pkg-config`。

安装 Flutter 依赖：

```bash
flutter pub get
```

macOS 安装 FFmpeg 构建依赖：

```bash
brew install nasm pkg-config
```

运行 macOS 开发版：

```bash
flutter run -d macos
```

运行 Windows 开发版：

```powershell
flutter run -d windows
```

如果修改 Drift 表结构或需要重新生成代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

命令行压缩验证入口：

```bash
dart run tool/machining_cli.dart compress ~/Movies/demo.mp4
dart run tool/machining_cli.dart compress ~/Movies/demo.mp4 --codec h265 --resolution 1080p
```

## 测试

运行静态分析：

```bash
flutter analyze
```

运行全部自动化测试：

```bash
flutter test
```

运行单个测试文件：

```bash
flutter test test/ffmpeg_command_builder_test.dart
```

当前测试重点：

- 压缩建议和输出体积估算。
- FFmpeg 命令构造。
- FFmpeg 编码器能力检测。
- FFmpeg 进程观测和任务队列执行。
- FFprobe 媒体分析。
- 预览帧和缩略图生成。

真实 FFmpeg / FFprobe 验证需要平台运行时文件。更完整的测试说明见 [docs/develop/test-plan.md](/Users/leftzhou/工作区/Machining/docs/develop/test-plan.md)。

## 怎么构建

构建前建议先执行：

```bash
flutter pub get
flutter analyze
flutter test
```

### macOS

准备 macOS arm64 FFmpeg / FFprobe：

```bash
scripts/build_ffmpeg_macos_arm64.sh
```

脚本会构建 FFmpeg 7.1.1 和 x264，并检查：

- 没有 Homebrew 动态库依赖。
- `libx264` 编码器可用。

必须存在的运行时路径：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
```

Release 构建：

```bash
flutter build macos --release
```

Release app 位置：

```text
build/macos/Build/Products/Release/Machining.app
```

验证 app 内置 FFmpeg：

```bash
APP="build/macos/Build/Products/Release/Machining.app"
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -version
"$APP/Contents/Resources/ffmpeg/ffprobe" -hide_banner -version
```

### Windows

Windows 构建前必须准备：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

Release 构建：

```powershell
flutter build windows --release
```

Release 产物位置：

```text
build/windows/x64/runner/Release/
```

Windows CMake 会把运行时复制到：

```text
build/windows/x64/runner/Release/ffmpeg/
```

如果 `ffmpeg.exe` 或 `ffprobe.exe` 不存在，Windows Release 构建会失败，避免产出缺少内置运行时的发布包。

验证 app 内置 FFmpeg：

```powershell
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -version
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe -hide_banner -version
```

## FFmpeg / FFprobe 运行时

Machining 解析运行时时的优先级：

1. 用户自定义路径。
2. 应用包内置路径。
3. 常见系统安装路径。
4. 系统 `PATH`。

仓库预留的内置运行时位置：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

这些二进制文件不提交到 Git。仓库只保留目录说明、构建脚本和构建信息。

macOS Release app 内的运行时位置：

```text
Machining.app/Contents/Resources/ffmpeg/
```

Windows Release 目录内的运行时位置：

```text
machining.exe 同级目录/ffmpeg/
```

## GPU 编码加速

Machining 会执行：

```bash
ffmpeg -hide_banner -encoders
```

并根据输出判断当前 FFmpeg 支持哪些硬件编码器。任务配置为“自动选择”时，会优先使用可用的 GPU 编码器；如果当前电脑或 FFmpeg 不支持对应编码器，会回退到 CPU 编码。

macOS 自动选择优先级：

```text
VideoToolbox -> libx264 / libx265
```

Windows 自动选择优先级：

```text
NVIDIA NVENC -> Intel Quick Sync -> AMD AMF -> libx264 / libx265
```

## 项目结构

项目采用接近 Clean Architecture 的分层结构，让 UI、业务规则、数据存储和 FFmpeg 进程调用分开。

```text
lib/
  app/                 应用入口、路由和全局配置
  domain/              实体、枚举和值对象
  application/         仓储接口、媒体分析、命令构造、队列执行等服务抽象
  infrastructure/      Drift 数据库、FFmpeg / FFprobe、本地文件和进程实现
  features/workbench/  工作台页面、任务列表、配置弹窗和状态协调
```

核心流程：

```text
导入文件
  -> 校验媒体类型和源文件指纹
  -> 创建 MediaTask 并保存到 SQLite
  -> FFprobe 分析媒体信息
  -> 生成缩略图和预览素材
  -> 根据任务配置构造 FFmpeg 命令
  -> 队列启动 FFmpeg 进程
  -> 解析进度并写回任务状态
  -> 完成后记录输出路径或失败信息
```

更多架构说明见 [docs/develop/architecture.md](/Users/leftzhou/工作区/Machining/docs/develop/architecture.md)。

## 文档

文档入口在 [docs/README.md](/Users/leftzhou/工作区/Machining/docs/README.md)。

常用文档：

- [docs/product/roadmap.md](/Users/leftzhou/工作区/Machining/docs/product/roadmap.md)：产品路线图和下一阶段规划。
- [docs/develop/architecture.md](/Users/leftzhou/工作区/Machining/docs/develop/architecture.md)：项目架构和模块边界。
- [docs/develop/technology-stack.md](/Users/leftzhou/工作区/Machining/docs/develop/technology-stack.md)：技术栈、依赖和平台范围。
- [docs/develop/data-model.md](/Users/leftzhou/工作区/Machining/docs/develop/data-model.md)：数据库 schema、任务模型和设置模型。
- [docs/develop/test-plan.md](/Users/leftzhou/工作区/Machining/docs/develop/test-plan.md)：自动化测试和手动验证计划。
- [docs/reference/ffmpeg-license-distribution.md](/Users/leftzhou/工作区/Machining/docs/reference/ffmpeg-license-distribution.md)：FFmpeg、x264、GPL 路线和分发参考。

## 许可说明

项目当前内置 FFmpeg + x264 构建路线。包含该运行时的发布包需要遵守对应 FFmpeg 构建的 GPL 许可要求。FFmpeg、x264 等依赖归各自原项目维护，Machining 只调用并随应用分发相应运行时。

详细说明见 [docs/reference/ffmpeg-license-distribution.md](/Users/leftzhou/工作区/Machining/docs/reference/ffmpeg-license-distribution.md)。
