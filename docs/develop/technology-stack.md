# 技术栈与开发环境

## 文档目的

这份文档记录 FrameLean 当前使用的开发环境、框架、核心依赖、运行时和技术边界。

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
| 状态管理 | Flutter Riverpod 3 | 已使用 | Provider / AsyncNotifier / Notifier 管理依赖装配、FFmpeg 运行时、任务列表和预览状态 |
| 路由 | GoRouter | 已使用 | 当前 `/` 指向工作台，应用设置通过工作台弹窗打开 |
| 架构风格 | 接近 Clean Architecture 的分层 | 已使用 | `domain`、`application`、`infrastructure`、`features` 分层 |
| 本地数据库 | Drift + SQLite | 已使用 | 保存任务和设置，当前 schema version 为 20 |
| 原生 SQLite | sqlite3 native assets / sqlite3_flutter_libs | 已使用 | 桌面端 Drift SQLite 运行依赖 |
| 媒体分析 | FFprobe | 已使用 | 读取视频、图片、音频的时长、编码、码率、尺寸、音频、封装、色彩、HDR10 静态元数据和 Dolby Vision profile 信息 |
| 媒体处理 | FFmpeg + libzimg | 已使用 | 生成视频预览帧、视频缩略图、媒体压缩和格式转换；HDR10 / HLG 转 SDR 依赖 `zscale` / `tonemap` |
| 媒体类型识别 | 文件扩展名映射 | 已使用 | 视频、图片、音频和部分专有音频输入扩展名会进入任务流程 |
| 专有音频输入 | Dart 原生 NCM + 外部 QMC 适配器 | 已使用 | NCM 使用本地 Dart 解密；MGG / MFLAC 等 QMC 输入通过适配器或 `qmc-decrypt` 预处理 |
| 文件选择 | file_selector | 已使用 | 底部导入按钮选择本地文件 |
| 桌面拖拽 | desktop_drop | 已使用 | 工作台拖入文件创建任务 |
| UI 动画 | flutter_animate | 已使用 | 工作台右上角通知的进入 / 退出动画，并作为后续动效基础 |
| 任务完成音效 | Flutter assets + 系统播放器 | 已使用 | 内置 WAV 资源打包到 `assets/sounds/`；macOS 使用 `afplay`，Windows 使用 `SoundPlayer` |
| 响应式尺寸 | flutter_screenutil | 已使用 | 工作台和主题文本使用桌面基准尺寸，允许小窗口缩小但不随大窗口放大 |
| 主题系统 | ThemeExtension + settings.theme_mode + theme_prefs.json | 已使用 | 工作台支持浅色 / 深色主题切换；`settings.theme_mode` 是权威设置，`theme_prefs.json` 只作为首帧缓存镜像，启动后会异步按 DB 自愈 |
| 路径处理 | path / path_provider | 已使用 | 数据库路径、输出路径、临时目录、主题缓存路径和文件名处理 |
| ID 生成 | uuid | 已使用 | `MediaTask.id` 使用 UUID |
| macOS 打包 | Flutter macOS + Universal 2 runtime + Xcode build phase | 已使用 | Release app 只复制同时包含 x86_64 / arm64 的 FFmpeg 运行时 |
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
| `flutter_animate` | `^4.5.2` | 声明式 UI 动画，当前用于工作台通知浮层 |
| `flutter_screenutil` | `^5.9.3` | 桌面 UI 文本和尺寸适配 |
| `pointycastle` | `^4.0.0` | NCM 专有音频输入的本地加密/解密算法支持 |
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
    repositories/
    services/input_runtime/
    services/ffmpeg_planning/
    services/execution/
    use_cases/app_settings/
    use_cases/media_tasks/
  infrastructure/
    database/
    providers/
    repositories/
    services/input_runtime/
    services/ffmpeg_planning/
    services/execution/
  features/
    workbench/
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

当前主要验证平台是 macOS Universal 2（Intel x86_64 + Apple Silicon arm64）和 Windows x64。Linux 和 Web 目录来自 Flutter 工程结构，不代表已经完成发布支持。

## 开发环境

基础要求：

| 环境 | 说明 |
| --- | --- |
| Flutter SDK | 需要满足 Dart SDK `^3.11.0` |
| macOS 开发 | 需要 Xcode Command Line Tools；构建内置 FFmpeg 时需要 Homebrew、`nasm`、`pkg-config`；zimg tag archive 如缺少 `configure`，还需要 `autoconf` / `automake` / `libtool` |
| Windows 开发 | 需要 Visual Studio C++ 桌面构建工具和 Flutter Windows 桌面支持 |
| FFmpeg / FFprobe | 开发运行可使用 custom、bundled、known system 或 PATH 中的工具；发布包应包含内置运行时 |

常用命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
scripts/release/build_dmg_macos.sh
```

Windows 常用命令：

```powershell
flutter run -d windows
PowerShell -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1
```

GitHub Actions Windows 打包：

```text
.github/workflows/build-windows.yml
```

该 workflow 会在 Windows runner 上下载 `deps-ffmpeg-windows-x64-20260430`
Release 中的 FFmpeg 运行时 zip 并校验 SHA-256，按锁定 commit 构建 Windows
QMC 适配器，然后调用唯一发布入口 `scripts\release\build_windows.ps1`。一次
Flutter Release 构建会生成便携 ZIP 和 Inno Setup 安装器，两个产物都会上传为
Action artifact；Tag 构建还会把两个产物附加到 GitHub Release。

Windows Release 脚本会从 Visual Studio Redistributable 目录装入
`msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`。三个 DLL 是 ZIP
和安装器的必需文件，缺失时发布构建失败。

Windows 安装器使用 `{localappdata}\Programs\FrameLean` 作为固定默认目录，
并保持 `PrivilegesRequired=lowest`，不再允许切换管理员安装模式。该边界让
后续自托管静默覆盖更新保持当前用户权限，避免正常升级流程触发 UAC。

脚本职责和正式发布入口见 `scripts/README.md`。

## 核心依赖位置

Flutter 和 Dart 依赖声明位于：

```text
pubspec.yaml
```

FFmpeg 运行时说明位于：

```text
third_party/ffmpeg/macos-arm64/README.md
third_party/ffmpeg/macos-x64/README.md
third_party/ffmpeg/macos-universal/README.md
third_party/ffmpeg/windows-x64/README.md
docs/reference/ffmpeg-license-distribution.md
```

## FFmpeg / FFprobe 运行时

运行时定位逻辑由 `LocalFfmpegLocator` 实现：

```text
lib/infrastructure/services/input_runtime/local_ffmpeg_locator.dart
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
| macOS | 默认 VideoToolbox，然后回退到 `libx264` / `libx265`；Apple HDR / HVC1 / 10-bit MOV 等高风险源会优先走可用的软件编码 |
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
| 图片编码 | `libwebp` |
| 音频编码 | `libmp3lame`、`aac`、`aac_at`、`libopus`、`pcm_s16le`、`flac`、`pcm_s16be`、`wmav2` |

图片和音频输出命令按目标格式推导编码器；其中 WebP 依赖 `libwebp`，MP3 依赖 `libmp3lame`，Opus / Ogg Opus 依赖 `libopus`。如果当前 FFmpeg 缺少目标格式对应的编码器，命令规划会在启动 FFmpeg 前失败并给出可读提示。

视频色彩处理规则：

- SDR 源优先保留 FFprobe 读取到的 range、matrix、transfer 和 primaries；缺失时按分辨率推断 BT.709 或 SD 的 SMPTE 170M，不再统一硬贴 BT.709。
- HDR10 / HLG 源通过 `zscale + tonemap` 转为 SDR BT.709 输出，依赖 FFmpeg 启用 `libzimg` 并暴露 `zscale`、`tonemap` 滤镜。
- Dolby Vision Profile 5 或缺少 HDR10 兼容层的 Dolby Vision 首版直接拒绝命令构造，避免输出变黑、偏紫或严重偏色。
- 硬件编码器质量参数独立映射：CRF、NVENC CQ、QSV global quality、AMF QP 和 VideoToolbox `q:v` 不再共用同一个数值。

## 平台打包事实

### macOS

macOS FFmpeg 架构切片和正式运行时目录：

```text
third_party/ffmpeg/macos-arm64/
third_party/ffmpeg/macos-x64/
third_party/ffmpeg/macos-universal/
```

每个目录保留对应构建信息；正式发布使用的 `macos-universal` 应包含：

```text
ffmpeg
ffprobe
ffmpeg-build-info.txt
README.md
```

运行时构建脚本：

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

DMG 打包脚本：

```text
scripts/release/build_dmg_macos.sh
```

Xcode 中存在 `Bundle FFmpeg Runtime` build phase，会把可执行文件复制到：

```text
FrameLean.app/Contents/Resources/ffmpeg/
```

Xcode 中也存在 `Bundle Legal Materials` build phase，会把 `legal/`、`LICENSE` 和 `legal/NOTICE.md` 复制到：

```text
FrameLean.app/Contents/Resources/legal/
```

当前 macOS FFmpeg build phase 只读取 `macos-universal`。`scripts/release/build_dmg_macos.sh` 会在打包前验证 Universal FFmpeg，显式构建 Release app，扫描包内全部 Mach-O 文件均包含 x86_64 / arm64，再进入签名、公证和 DMG 生成步骤。

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
<FrameLean.exe 所在目录>/ffmpeg/
```

Windows 构建时如果 `ffmpeg.exe` 或 `ffprobe.exe` 缺失，CMake 会直接 `FATAL_ERROR`，避免生成缺少运行时的 Release 包。`scripts/release/build_windows.ps1` 会在构建后检查 Release 目录内 FFmpeg 是否包含 `libx264`、`libmp3lame`、`libwebp`、`libopus`，以及 HDR 转 SDR 需要的 `zscale`、`tonemap` 滤镜。

## 数据与文件存储

| 数据 | 位置 / 机制 | 说明 |
| --- | --- | --- |
| 任务与设置 | 应用支持目录下的 `framelean.sqlite` | Drift + SQLite 管理 |
| FFmpeg 执行日志 | 系统临时目录 `framelean/ffmpeg-logs` | 每次执行创建独立日志文件 |
| 预览帧 | 系统临时目录 `framelean/previews/<taskId>` | 参数指纹变化后重新生成 |
| 两遍压缩 pass log | 输出目录附近的隐藏前缀文件 | 任务完成或取消后 best-effort 清理 |
| 输出文件 | 用户配置目录或源文件目录 | 路径冲突时自动追加 `-1`、`-2` 等后缀 |

## 媒体类型边界

`FileExtensionMediaKindResolver` 目前按扩展名识别媒体类型：

| 类型 | 扩展名 |
| --- | --- |
| 视频 | `.mp4`、`.mov`、`.mkv`、`.avi`、`.webm`、`.m4v`、`.flv`、`.wmv`、`.mpg`、`.mpeg`、`.ts`、`.m2ts`、`.mts`、`.3gp`、`.3g2`、`.vob`、`.ogv`、`.dv`、`.asf` |
| 图片 | `.jpg`、`.jpeg`、`.png`、`.webp`、`.gif`、`.bmp`、`.tif`、`.tiff`、`.heic`、`.heif`、`.avif`、`.ico`、`.tga` |
| 音频 | `.mp3`、`.wav`、`.aac`、`.flac`、`.m4a`、`.ogg`、`.oga`、`.opus`、`.weba`、`.aiff`、`.aif`、`.aifc`、`.wma`、`.amr`、`.ape`、`.alac`、`.caf`、`.au`、`.wv`、`.tta` |
| 专有音频输入 | `.ncm`、`.mgg`、`.mgg0`、`.mgg1`、`.mggl`、`.mflac`、`.mflac0`、`.qmcflac` |

工作台当前允许 `video`、`image`、`audio` 进入任务队列。视频保留完整配置、预览和缩略图主链路；图片和音频当前支持导入、分析、分类型配置面板、处理执行和通用完成弹窗。

专有音频输入只作为导入格式，不进入 `MediaOutputFormat` 输出列表。`.ncm` 由 `NativeNcmAudioDecoder` 使用 Dart + `pointycastle` 在本地还原为临时 MP3 / FLAC；`.mgg`、`.mflac` 等 QMC 变体通过 `framelean-qmc-adapter` 或直接放置的 `qmc-decrypt` 外部运行时处理，再交给 FFprobe / FFmpeg 走标准音频链路。

## 当前核心功能对应实现

| 功能 | 主要代码 |
| --- | --- |
| 工作台 UI | `lib/features/workbench/pages/workbench_page.dart` 和 `lib/features/workbench/pages/workbench_page/` 下的布局、弹窗、覆盖层与配置组件 |
| 任务列表状态入口 | `lib/features/workbench/providers/media_task_notifier.dart`，通过 media task use cases 进入 application |
| 预览状态入口 | `lib/features/workbench/providers/workbench_preview_notifier.dart`，通过 `GeneratePreviewFramesUseCase` 进入 application |
| 任务仓储 | `lib/application/repositories/media_task_repository.dart`、`lib/infrastructure/repositories/drift_media_task_repository.dart` |
| 设置仓储 | `lib/application/repositories/app_settings_repository.dart`、`lib/infrastructure/repositories/drift_app_settings_repository.dart` |
| 持久化兼容映射 | `lib/infrastructure/database/persistence_compatibility.dart`、`lib/infrastructure/repositories/mappers/compression_mode_mapper.dart`、`lib/infrastructure/repositories/mappers/media_task_config_json_mapper.dart` |
| 媒体类型识别 | `FileExtensionMediaKindResolver` |
| 专有音频输入适配 | `DefaultMediaInputPreparer`、`ProprietaryAudioDecoderDispatcher`、`NativeNcmAudioDecoder`、`BundledProprietaryAudioAdapterRegistry` |
| FFprobe 分析 | `FfprobeMediaAnalyzer` |
| 压缩建议 | `DefaultCompressionAdvisor` |
| FFmpeg 命令构造 | `DefaultFfmpegCommandBuilder` 和 `services/ffmpeg_planning/` 下的命令规划 helper |
| 队列执行 | `DefaultFfmpegTaskQueueRunner` |
| 进程控制 | `FfmpegProcessController`；macOS / Linux 使用 signal，Windows 使用 runner method channel 调用原生线程挂起 / 恢复 |
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
- Application use cases。
- 持久化兼容映射。
- 工作台预览状态和弹窗风格。
- Widget 基础构建和关键交互。

完整测试范围见：

```text
docs/develop/test-plan.md
```

## 技术边界

- 当前产品实现仍以本地媒体处理为主，暂不包含云端转码、账号体系或多设备同步。
- 视频任务是最完整的能力面；图片和音频已支持基础本地处理，但暂不包含图片高级编辑、音频波形、试听、多轨或字幕能力。
- Linux 和 Web 目录不是当前发布目标；涉及平台行为时不要默认它们已经可用。
- 应用设置通过工作台弹窗打开，不保留未完成设置页占位路由。
- FFmpeg 二进制通常不应提交到 Git；本地和发布构建需要按 `third_party/ffmpeg/*/README.md` 准备运行时。
- 内置 FFmpeg + x264 的发布路线需要遵守 GPL 相关分发要求，见 `docs/reference/ffmpeg-license-distribution.md`。

## 给 AI 的使用说明

AI 在处理代码任务时，应优先阅读：

1. `CONTEXT.md`
2. `docs/README.md`
3. `docs/develop/architecture.md`
4. `docs/develop/data-model.md`
5. `docs/develop/test-plan.md`

不要把旧计划、旧任务清单或历史提交记录直接当成当前实现事实。版本形成的稳定事实看 `docs/releases/`，重要决策看 `docs/decisions/`，可复用经验看 `docs/lessons.md`。
