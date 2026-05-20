# 技术栈与开发环境

## 文档目的

这份文档记录 Machining 当前使用的开发环境、框架、核心依赖、运行时和技术边界。

它同时面向开发者和 AI：

1. 开发者可以快速确认项目需要哪些基础环境。
2. AI 可以先阅读本文件，减少对生成目录和平台目录的重复扫描。
3. 后续引入新依赖或调整技术方案时，可以在这里同步更新项目事实。

## 状态说明

| 状态 | 含义 |
| --- | --- |
| 已使用 | 已经写入项目配置或源码，并且当前项目正在使用 |
| 计划使用 | 已有明确方向，但还没有正式落地 |
| 候选方案 | 可以考虑，但尚未决定 |

AI 在理解项目时，应以“已使用”为当前事实，不要把“计划使用”或“候选方案”当成已经完成的实现。

## 当前技术栈总览

| 模块 | 技术 | 当前状态 | 说明 |
| --- | --- | --- | --- |
| 桌面客户端 | Flutter Desktop | 已使用 | 当前主应用框架 |
| 客户端语言 | Dart 3.11 约束 | 已使用 | `pubspec.yaml` 中 `environment.sdk: ^3.11.0` |
| 状态管理 | Flutter Riverpod 3 | 已使用 | Provider / AsyncNotifier 管理数据库、FFmpeg 运行时和工作台任务列表 |
| 路由 | GoRouter | 已使用 | 当前 `/` 指向工作台，应用设置通过工作台弹窗打开 |
| 架构风格 | 接近 Clean Architecture 的分层 | 已使用 | `domain`、`application`、`infrastructure`、`features` 分层 |
| 本地数据库 | Drift + SQLite | 已使用 | 保存任务和设置，当前 schema version 为 10 |
| 原生 SQLite | sqlite3 native assets / sqlite3_flutter_libs | 已使用 | 桌面端 Drift SQLite 运行依赖 |
| 媒体分析 | FFprobe | 已使用 | 读取时长、编码、码率、分辨率、音频和封装信息 |
| 媒体处理 | FFmpeg | 已使用 | 生成预览帧、缩略图、压缩和转封装 |
| 媒体类型识别 | 文件扩展名映射 | 已使用 | 视频扩展名会进入任务流程，图片和音频当前识别后拒绝处理 |
| 文件选择 | file_selector | 已使用 | 底部导入按钮选择本地文件 |
| 桌面拖拽 | desktop_drop | 已使用 | 工作台拖入文件创建任务 |
| 路径处理 | path / path_provider | 已使用 | 数据库路径、输出路径、临时目录和文件名处理 |
| ID 生成 | uuid | 已使用 | `MediaTask.id` 使用 UUID |
| macOS 打包 | Flutter macOS + Xcode build phase | 已使用 | Release app 可复制 macOS arm64 FFmpeg 运行时 |
| Windows 打包 | Flutter Windows + CMake install | 已使用 | Release 目录强制包含 Windows x64 FFmpeg 运行时 |
| Linux / Web | Flutter 默认平台目录 | 候选方案 | 目录存在，但不是当前验证和发布目标 |

## 依赖清单

依赖声明位于 `pubspec.yaml`。当前直接依赖：

| 依赖 | 版本约束 | 用途 |
| --- | --- | --- |
| `flutter_riverpod` | `^3.3.1` | 状态管理、依赖注入、异步任务列表和运行时解析 |
| `go_router` | `^17.2.2` | 应用路由 |
| `uuid` | `^4.5.3` | 任务 ID |
| `drift` | `^2.32.1` | 类型安全 SQLite ORM |
| `sqlite3_flutter_libs` | `^0.6.0+eol` | SQLite 原生库支持 |
| `path_provider` | `^2.1.5` | 获取应用支持目录 |
| `path` | `^1.9.1` | 跨平台路径拼接和规范化 |
| `args` | `^2.7.0` | 命令参数工具依赖，目前保留在项目依赖中 |
| `file_selector` | `^1.1.0` | 桌面文件选择 |
| `desktop_drop` | `^0.7.1` | 桌面拖拽导入 |
| `cupertino_icons` | `^1.0.8` | Flutter 默认图标依赖 |

开发依赖：

| 依赖 | 版本约束 | 用途 |
| --- | --- | --- |
| `flutter_test` | Flutter SDK | Widget 和单元测试 |
| `flutter_lints` | `^6.0.0` | 静态分析规则 |
| `drift_dev` | `^2.32.1` | Drift 代码生成 |
| `build_runner` | `^2.14.1` | 代码生成执行器 |
| `flutter_launcher_icons` | `^0.14.4` | macOS / Windows 应用图标生成 |
| `dmg` | `^0.1.8` | macOS DMG 打包辅助依赖 |

## 项目目录结构

主要源码目录：

```text
lib/
  app/
  domain/
  application/
  infrastructure/
  features/
```

各层职责详见 `docs/develop/architecture.md`。

主要平台和工程目录：

```text
macos/
windows/
linux/
web/
test/
scripts/
third_party/
```

当前主要验证平台是 macOS Apple Silicon 和 Windows x64。Linux 和 Web 目录来自 Flutter 工程结构，不代表已经完成发布支持。

## 开发环境

基础要求：

| 环境 | 说明 |
| --- | --- |
| Flutter SDK | 需要满足 Dart SDK `^3.11.0` |
| macOS 开发 | 需要 Xcode Command Line Tools；构建内置 FFmpeg 时需要 Homebrew、`nasm`、`pkg-config` |
| Windows 开发 | 需要 Visual Studio C++ 桌面构建工具和 Flutter Windows 桌面支持 |
| FFmpeg / FFprobe | 开发运行可使用 custom、bundled、known system 或 PATH 中的工具；发布包应包含内置运行时 |

常用命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
scripts/build_dmg_macos.sh
```

Windows 常用命令：

```powershell
flutter run -d windows
PowerShell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

## 核心依赖位置

Flutter 和 Dart 依赖声明位于：

```text
pubspec.yaml
```

FFmpeg 运行时说明位于：

```text
third_party/ffmpeg/macos-arm64/README.md
third_party/ffmpeg/windows-x64/README.md
docs/reference/ffmpeg-license-distribution.md
```

## FFmpeg / FFprobe 运行时

运行时定位逻辑由 `LocalFfmpegLocator` 实现：

```text
lib/infrastructure/services/local_ffmpeg_locator.dart
```

解析顺序：

1. 用户设置的自定义 `ffmpeg` / `ffprobe` 路径。
2. 应用包或可执行文件旁边的内置运行时。
3. 平台常见系统路径。
4. 系统 `PATH` 中的 `ffmpeg` / `ffprobe`。

定位到 FFmpeg 后，应用会执行：

```bash
ffmpeg -hide_banner -encoders
```

然后由 `FfmpegEncoderCapabilities` 解析可用编码器。自动编码器后端优先级：

| 平台 | 自动优先级 |
| --- | --- |
| macOS | VideoToolbox，然后回退到 `libx264` / `libx265` |
| Windows | NVENC、Quick Sync、AMF，然后回退到 `libx264` / `libx265` |
| Linux | 当前没有额外硬件优先级，默认软件编码 |

支持的编码器名称：

| 类型 | 编码器 |
| --- | --- |
| 软件编码 | `libx264`、`libx265` |
| macOS 硬件编码 | `h264_videotoolbox`、`hevc_videotoolbox` |
| NVIDIA | `h264_nvenc`、`hevc_nvenc` |
| Intel Quick Sync | `h264_qsv`、`hevc_qsv` |
| AMD AMF | `h264_amf`、`hevc_amf` |

## 平台打包事实

### macOS

macOS FFmpeg 运行时目录：

```text
third_party/ffmpeg/macos-arm64/
```

该目录应包含：

```text
ffmpeg
ffprobe
ffmpeg-build-info.txt
README.md
```

运行时构建脚本：

```text
scripts/build_ffmpeg_macos_arm64.sh
```

DMG 打包脚本：

```text
scripts/build_dmg_macos.sh
```

Xcode 中存在 `Bundle FFmpeg Runtime` build phase，会把可执行文件复制到：

```text
Machining.app/Contents/Resources/ffmpeg/
```

Xcode 中也存在 `Bundle Legal Materials` build phase，会把 `legal/`、`LICENSE` 和 `NOTICE` 复制到：

```text
Machining.app/Contents/Resources/legal/
```

当前 macOS FFmpeg build phase 在二进制缺失时会输出 warning 并跳过复制；`scripts/build_dmg_macos.sh` 会在打包前检查并准备运行时，打包后验证 Release app 中存在 `ffmpeg`、`ffprobe` 和法律资料。

### Windows

Windows FFmpeg 运行时目录：

```text
third_party/ffmpeg/windows-x64/
```

该目录应包含：

```text
ffmpeg.exe
ffprobe.exe
README.md
```

`windows/CMakeLists.txt` 会把这两个文件安装到：

```text
<machining.exe 所在目录>/ffmpeg/
```

Windows 构建时如果 `ffmpeg.exe` 或 `ffprobe.exe` 缺失，CMake 会直接 `FATAL_ERROR`，避免生成缺少运行时的 Release 包。

## 数据与文件存储

| 数据 | 位置 / 机制 | 说明 |
| --- | --- | --- |
| 任务与设置 | 应用支持目录下的 `machining.sqlite` | Drift + SQLite 管理 |
| FFmpeg 执行日志 | 系统临时目录 `machining/ffmpeg-logs` | 每次执行创建独立日志文件 |
| 预览帧 | 系统临时目录 `machining/previews/<taskId>` | 参数指纹变化后重新生成 |
| 两遍压缩 pass log | 输出目录附近的隐藏前缀文件 | 任务完成或取消后 best-effort 清理 |
| 输出文件 | 用户配置目录或源文件目录 | 路径冲突时自动追加 `-1`、`-2` 等后缀 |

## 媒体类型边界

`ExtensionMediaKindResolver` 目前按扩展名识别媒体类型：

| 类型 | 扩展名 |
| --- | --- |
| 视频 | `.mp4`、`.mov`、`.mkv`、`.avi`、`.webm`、`.m4v` |
| 图片 | `.jpg`、`.jpeg`、`.png`、`.webp`、`.gif`、`.bmp` |
| 音频 | `.mp3`、`.wav`、`.aac`、`.flac`、`.m4a`、`.ogg` |

工作台当前只允许 `video` 进入任务队列。图片和音频枚举已存在，但导入时会被 `ensureSupportedMediaKind()` 拒绝。

## 当前核心功能对应实现

| 功能 | 主要代码 |
| --- | --- |
| 工作台 UI | `lib/features/workbench/pages/workbench_page.dart` 和同级拆分组件 |
| 任务列表状态 | `lib/features/workbench/providers/media_task_notifier.dart` |
| 任务仓储 | `lib/application/repositories/media_task_repository.dart`、`lib/infrastructure/repositories/drift_media_task_repository.dart` |
| 设置仓储 | `lib/application/repositories/app_settings_repository.dart`、`lib/infrastructure/repositories/drift_app_settings_repository.dart` |
| 媒体类型识别 | `ExtensionMediaKindResolver` |
| FFprobe 分析 | `FfprobeMediaAnalyzer` |
| 压缩建议 | `DefaultCompressionAdvisor` |
| FFmpeg 命令构造 | `DefaultFfmpegCommandBuilder` |
| 队列执行 | `DefaultFfmpegTaskQueueRunner` |
| 进度观测 | `LocalFfmpegProcessObserver` |
| 预览帧生成 | `LocalPreviewFrameGenerator` |
| 缩略图生成 | `LocalVideoThumbnailGenerator` |

## 测试与验证边界

自动化测试入口：

```bash
flutter analyze
flutter test
```

当前测试重点：

- 压缩建议和体积预估。
- FFmpeg 命令构造。
- 编码器能力解析。
- 队列启动、暂停、恢复、取消和串行执行。
- FFmpeg 进度观测。
- FFprobe 分析结果解析。
- 预览帧和缩略图生成。
- Widget 基础构建。

完整测试范围见：

```text
docs/develop/test-plan.md
```

## 技术边界

- 当前产品实现以本地视频压缩为主，不上传文件，也不依赖云端服务。
- 当前 UI 只允许视频任务；`image`、`audio` 枚举是预留模型，不代表已支持处理。
- Linux 和 Web 目录不是当前发布目标；涉及平台行为时不要默认它们已经可用。
- 设置页路由存在，但内容仍是占位。
- FFmpeg 二进制通常不应提交到 Git；本地和发布构建需要按 `third_party/ffmpeg/*/README.md` 准备运行时。
- 内置 FFmpeg + x264 的发布路线需要遵守 GPL 相关分发要求，见 `docs/reference/ffmpeg-license-distribution.md`。

## 给 AI 的使用说明

AI 在处理代码任务时，应优先阅读：

1. `docs/README.md`
2. `docs/develop/architecture.md`
3. `docs/develop/data-model.md`
4. `docs/develop/test-plan.md`

不要把 `archive/` 中的历史日志直接当成当前实现事实。
