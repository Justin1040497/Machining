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
| 状态管理 | Flutter Riverpod 3 | 已使用 | Provider / AsyncNotifier / Notifier 管理依赖装配、FEngine 生命周期、任务列表和预览状态 |
| 路由 | GoRouter | 已使用 | 当前 `/` 指向工作台，应用设置通过 `/settings` 全屏页面打开 |
| 架构风格 | 接近 Clean Architecture 的分层 | 已使用 | `domain`、`application`、`infrastructure`、`features` 分层 |
| 本地数据库 | Drift + SQLite | 已使用 | 保存任务、设置、Engine 投影和应用通知，当前 schema version 为 35 |
| 原生 SQLite | sqlite3 native assets / sqlite3_flutter_libs | 已使用 | 桌面端 Drift SQLite 运行依赖 |
| 媒体分析 | FEngine + FLL libav | 已使用 | FLL 进程内读取媒体事实并返回冻结 AnalysisSnapshot |
| 媒体 artifact | FEngine Control queue + FLL libavcodec/libswscale | 已使用 | 生成源媒体预览帧和非黑帧视频缩略图 BMP |
| 媒体执行 | FEngine + FLL Runtime | 部分可用 | packet stream-copy/remux 可执行；完整转码链未就绪时 fail closed |
| 媒体类型识别 | 文件扩展名映射 | 已使用 | 视频、图片、音频和部分专有音频输入扩展名会进入任务流程 |
| 专有音频输入 | Dart 原生 NCM + 外部 QMC 适配器 | 已使用 | NCM 使用本地 Dart 解密；MGG / MFLAC 等 QMC 输入通过适配器或 `qmc-decrypt` 预处理 |
| 文件选择 | file_selector + file_picker | 已使用 | `file_selector` 继续用于常规文件 / 文件夹 / 输出目录选择；`file_picker` 用于 macOS 同一对话框多选文件和文件夹 |
| 快捷键 | hotkey_manager | 已使用 | 注册应用内快捷键并提供快捷键录入能力，避免依赖页面焦点树 |
| 桌面拖拽 | desktop_drop | 已使用 | 工作台拖入文件创建任务 |
| UI 动画 | flutter_animate | 已使用 | 工作台右上角通知的进入 / 退出动画，并作为后续动效基础 |
| 任务完成音效 | Flutter assets + audioplayers | 已使用 | 内置 WAV 资源打包到 `assets/sounds/`，通过 Flutter 音频插件播放，不启动 PowerShell |
| 桌面窗口生命周期 | window_manager + tray_manager | 已使用 | 拦截窗口关闭，按设置退出或最小化到后台；Windows 使用托盘恢复，macOS 通过 Dock 重新打开窗口 |
| 响应式尺寸 | flutter_screenutil | 已使用 | 工作台和主题文本使用桌面基准尺寸，小窗口可缩小，4K / 大窗口可在上限内放大 |
| 主题系统 | ThemeExtension + settings.theme_mode + theme_prefs.json | 已使用 | 工作台支持浅色 / 深色主题切换；`settings.theme_mode` 是权威设置，`theme_prefs.json` 只作为首帧缓存镜像，启动后会异步按 DB 自愈 |
| 路径处理 | path / path_provider | 已使用 | 数据库路径、输出路径、临时目录、主题缓存路径和文件名处理 |
| ID 生成 | uuid | 已使用 | `MediaTask.id` 使用 UUID |
| macOS 打包 | Flutter macOS + CocoaPods + Universal 2 FEngine | 已使用 | Release app 携带静态链接 bundled libav 的 Universal `framelean-engine` |
| 应用更新 | 外部下载地址优先；JSON latest / ticket package 链和 Sparkle 2 可选保留 | 已使用 | 默认检查更新后展示版本日志与 GitHub / Gitee / 备用下载入口；只有 release 没有外部地址且 package 元数据完整时，才下载 Windows 安装器或把 macOS DMG 保存到应用私有目录；Sparkle appcast 仅在显式启用并提供签名时使用 |
| Windows 打包 | Flutter Windows + CMake install | 已使用 | Release 目录携带静态链接 bundled libav 的 Windows x64 FEngine |
| Linux / Web | 不在当前范围 | 不支持 | 仓库不保留对应 Flutter 平台工程 |

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
| `file_selector` | `^1.1.0` | 桌面文件、文件夹和输出目录选择 |
| `file_picker` | `^11.0.2` | macOS 文件和文件夹混合多选导入 |
| `desktop_drop` | `^0.7.1` | 桌面拖拽导入 |
| `flutter_animate` | `^4.5.2` | 声明式 UI 动画，当前用于工作台通知浮层 |
| `flutter_screenutil` | `^5.9.3` | 桌面 UI 文本和尺寸适配 |
| `audioplayers` | `^6.7.1` | 播放内置任务完成提示音 |
| `window_manager` | `^0.5.1` | 桌面窗口关闭拦截、隐藏、显示和销毁 |
| `tray_manager` | `^0.2.4` | Windows 后台运行时的托盘图标和菜单 |
| `hotkey_manager` | `^0.2.3` | 应用内快捷键注册与快捷键录入 |
| `pointycastle` | `^4.0.0` | NCM 专有音频输入的本地加密/解密算法支持 |
| `crypto` | `^3.0.6` | 自托管更新包 SHA-256 校验 |
| `cryptography` | `^2.9.0` | Windows 自托管更新包 Ed25519 签名校验 |

开发依赖：

| 依赖 | 版本约束 | 用途 |
| --- | --- | --- |
| `flutter_test` | Flutter SDK | Widget 和单元测试 |
| `flutter_lints` | `^6.0.0` | 静态分析规则 |
| `drift_dev` | `^2.32.1` | Drift 代码生成 |
| `build_runner` | `^2.14.1` | 代码生成执行器 |
| `flutter_launcher_icons` | `^0.14.4` | macOS / Windows 应用图标生成 |
| `dmg` | `^0.1.8` | macOS DMG 打包辅助依赖 |

更新服务端位于 Monorepo 的 `backend/`。服务端框架、数据库、缓存、对象存储和 Admin Web 的具体依赖以该目录的 manifest 和源码为准；客户端继续只维护客户端 API、外部下载和保留 package 路线的契约。

## 项目目录结构

主要源码目录：

```text
lib/
  app/
    presentation/
    providers/
    widgets/
  domain/
  application/
    repositories/
    services/platform/
    services/input_runtime/
    services/execution/
    services/engine/
    use_cases/app_settings/
    use_cases/media_tasks/
  infrastructure/
    database/
    repositories/
    services/platform/
    services/input_runtime/
    services/execution/
    services/engine/
  features/
    workbench/
```

各层职责详见 `docs/develop/architecture.md`。

主要平台和工程目录：

```text
desktop-client/macos/
desktop-client/windows/
desktop-client/test/
scripts/
dependencies/
build/dependencies/
```

当前验证和发布平台是 macOS Universal 2（Intel x86_64 + Apple Silicon arm64）和 Windows x64。Linux 和 Web 不在当前支持范围，仓库不保留对应平台工程。

## 开发环境

基础要求：

| 环境 | 说明 |
| --- | --- |
| Flutter SDK | 需要满足 Dart SDK `^3.11.0` |
| macOS 开发 | 需要 Xcode Command Line Tools 和 CocoaPods；Release CI 使用 Flutter stable 并显式关闭 Swift Package Manager；构建 bundled static libav SDK 时需要 `autoconf`、`automake`、`libtool`、`nasm`、`pkg-config`；zimg tag archive 缺少 `configure` 时会通过 autotools 生成 |
| Windows 开发 | 需要 Visual Studio C++ 桌面构建工具和 Flutter Windows 桌面支持 |
| bundled static libav SDK | 只作为 FEngine 的显式构建输入；开发和发布均不得从系统、Homebrew 或 PATH 寻找 `ffmpeg` / `ffprobe` executable |

常用命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
../scripts/release/build_dmg_macos.sh
```

Windows 常用命令：

```powershell
flutter run -d windows
PowerShell -ExecutionPolicy Bypass -File ..\scripts\release\build_windows.ps1
```

GitHub Actions Windows 打包：

```text
.github/workflows/desktop-client.yml
```

该 workflow 通过 MSYS2/MinGW-w64 从源码编译 static libav SDK
（`scripts/build/build_ffmpeg_windows_x64.sh`），按锁定 commit 构建 Windows
QMC 适配器，然后调用唯一发布入口 `scripts\release\build_windows.ps1`。一次
Flutter Release 构建会生成便携 ZIP 和 Inno Setup 安装器，两个产物都会上传为
Action artifact；Tag 构建还会把两个产物附加到 GitHub Release。

Windows Release 脚本会从 Visual Studio Redistributable 目录装入
`msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`。三个 DLL 是 ZIP
和安装器的必需文件，缺失时发布构建失败。

Windows Release 脚本会从 `tools/windows_updater_helper.dart` 编译
`FrameLeanUpdaterHelper.exe` 并放入 Release 根目录。当前公开更新默认打开
外部下载地址；只有保留的 package 路线被启用时，客户端才在完成 SHA-256 和
Ed25519 校验后启动该 helper，由 helper 等待主进程退出、静默运行 Inno Setup
安装器、检查安装器退出码并重启应用。

Windows 安装器使用 `{localappdata}\Programs\FrameLean` 作为固定默认目录，
并保持 `PrivilegesRequired=lowest`，不再允许切换管理员安装模式。该边界让
后续自托管静默覆盖更新保持当前用户权限，避免正常升级流程触发 UAC。

脚本职责和正式发布入口见 `scripts/README.md`。

## 核心依赖位置

Flutter 和 Dart 依赖声明位于：

```text
pubspec.yaml
```

bundled static libav SDK 说明位于：

```text
build/dependencies/ffmpeg/macos-arm64/README.md
build/dependencies/ffmpeg/macos-x64/README.md
build/dependencies/ffmpeg/macos-universal/README.md
build/dependencies/ffmpeg/windows-x64/README.md
docs/reference/ffmpeg-license-distribution.md
```

## FEngine / bundled static libav 运行时

Desktop Client 不定位、不校验也不启动 `ffmpeg` / `ffprobe` executable。所有标准媒体能力经本机 FEngine Gateway 进入 FLL：

- 元数据、能力、候选、预设和估算来自 `AnalyzeMedia` 返回的 FLL Snapshot。
- 预览帧和视频缩略图通过 `EngineMediaGateway` 提交到 FEngine Control queue，由 FLL 使用 libavcodec / libswscale 生成 BMP artifact。
- 执行 selection 由 Client 按 Snapshot 展示并原样提交；Client 不生成 native 命令参数。
- 当前默认执行 Backend 支持兼容媒体的 packet stream-copy/remux、严格限定的单 SDR 视频加多条 PCM/AAC 音轨 -> H.264/AAC MP4，以及多条 PCM/AAC 音轨 -> AAC M4A。逐轨保留集合、AAC 码率、采样率和单/双声道由 Snapshot 候选参数域约束。多视频流、字幕/数据/附件、HDR、任意 Plugin Processor 桥接和其他未资格化转换组合返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`。

FEngine 正式构建使用仓库脚本生成的 bundled static libav SDK：

```text
build/dependencies/ffmpeg/macos-arm64/
build/dependencies/ffmpeg/macos-x64/
build/dependencies/ffmpeg/macos-universal/
build/dependencies/ffmpeg/windows-x64/
```

核心构建入口：

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
scripts/build/build_fengine_macos_arch.sh
scripts/build/build_fengine_macos_universal.sh
scripts/build/build_fengine_windows_x64.sh
scripts/build/with_bundled_ffmpeg.sh
```

这些 SDK 是构建输入，不是随 Desktop package 分发的 CLI 目录。构建不允许 system/Homebrew fallback。

## 平台打包事实

### macOS

正式包只携带 Universal 2 `framelean-engine`、Flutter 应用资源、法律资料和确有需要的专有音频适配器。构建对最终 FEngine 执行 `otool -L`，拒绝动态 `libav*.dylib` 依赖；应用包中不包含 `ffmpeg` / `ffprobe` executable。

macOS Flutter 插件原生依赖继续通过 CocoaPods 集成。仓库保留 `macos/Podfile`、`macos/Podfile.lock` 和 Runner workspace 的 Pods 引用；`pubspec.yaml` 固定关闭 Flutter Swift Package Manager。

### Windows

正式包只携带 `framelean-engine.exe`、Flutter runner、所需 Microsoft runtime、法律资料和确有需要的专有音频适配器。构建对最终 FEngine 执行 `objdump -p`，拒绝动态 libav 与 GNU runtime DLL；Release 目录中不包含 `ffmpeg.exe` / `ffprobe.exe`。

### Linux / Web

不是当前正式发布目标，仓库不保留对应 Flutter 平台工程。

## 数据与文件存储

| 数据 | 位置 / 机制 | 说明 |
| --- | --- | --- |
| 任务与设置 | 应用支持目录下的 `framelean.sqlite` | Drift + SQLite 管理 |
| FEngine 日志 | 系统临时目录 `framelean/engine-logs` | Client 日志查看入口使用的执行日志目录 |
| 预览帧 | 系统临时目录 `framelean/previews/<taskId>` | FLL 生成的 BMP artifact |
| 视频缩略图 | 系统临时目录 `framelean/thumbnails/<taskId>.bmp` | FLL 非黑帧缩略图 artifact |
| 输出文件 | 用户配置目录或源文件目录 | 路径冲突时自动追加 `（1）`、`（2）` 等后缀 |
| 更新安装包缓存 | 应用支持目录 `updates/<version>/<platform>/` | 保留 package 路线的下载缓存，支持断点续传、SHA-256 校验和 Windows Ed25519 验签；外部下载地址模式不写入该目录 |

服务端长期保存 release、版本日志、外部下载地址、审计和可选 package 元数据。缓存、对象存储、下载票据与 Admin 鉴权属于独立后端实现，本客户端仓库只依赖公开更新响应和相关安全约束。

## 媒体类型边界

`FileExtensionMediaKindResolver` 目前按扩展名识别媒体类型：

| 类型 | 扩展名 |
| --- | --- |
| 视频 | `.mp4`、`.mov`、`.mkv`、`.avi`、`.webm`、`.m4v`、`.flv`、`.wmv`、`.mpg`、`.mpeg`、`.ts`、`.m2ts`、`.mts`、`.3gp`、`.3g2`、`.vob`、`.ogv`、`.dv`、`.asf` |
| 图片 | `.jpg`、`.jpeg`、`.png`、`.webp`、`.gif`、`.bmp`、`.tif`、`.tiff`、`.heic`、`.heif`、`.avif`、`.ico`、`.tga` |
| 音频 | `.mp3`、`.wav`、`.aac`、`.flac`、`.m4a`、`.ogg`、`.oga`、`.opus`、`.weba`、`.aiff`、`.aif`、`.aifc`、`.wma`、`.amr`、`.ape`、`.alac`、`.caf`、`.au`、`.wv`、`.tta` |
| 专有音频输入 | `.ncm`、`.mgg`、`.mgg0`、`.mgg1`、`.mggl`、`.mflac`、`.mflac0`、`.qmcflac` |

工作台当前允许 `video`、`image`、`audio` 进入任务队列。视频保留完整配置、预览和缩略图主链路；图片和音频当前支持导入、分析、分类型配置面板、处理执行、任务项完成入口和通知中心结果回看。

专有音频输入只作为导入格式，不进入 `MediaOutputFormat` 输出列表。`.ncm` 由 `NativeNcmAudioDecoder` 使用 Dart + `pointycastle` 在本地还原为临时 MP3 / FLAC；`.mgg`、`.mflac` 等 QMC 变体通过专有音频适配器预处理，再把准备后的标准媒体路径提交给 FEngine。

## 当前核心功能对应实现

| 功能 | 主要代码 |
| --- | --- |
| 工作台 UI | `lib/features/workbench/pages/workbench_page.dart` 和 `lib/features/workbench/pages/workbench_page/` 下的布局、弹窗、覆盖层与配置组件 |
| 依赖组装 | `lib/app/providers/`，把 application 抽象绑定到 infrastructure 实现 |
| 桌面平台能力 | `lib/application/services/platform/` 抽象，`lib/infrastructure/services/platform/` 实现 |
| 任务列表状态入口 | `lib/features/workbench/providers/media_task_notifier.dart`，通过 media task use cases 进入 application |
| 预览状态入口 | `lib/features/workbench/providers/workbench_preview_notifier.dart`，通过 `GeneratePreviewFramesUseCase` 进入 application |
| 任务仓储 | `lib/application/repositories/media_task_repository.dart`、`lib/infrastructure/repositories/drift_media_task_repository.dart` |
| 设置仓储 | `lib/application/repositories/app_settings_repository.dart`、`lib/infrastructure/repositories/drift_app_settings_repository.dart` |
| 持久化兼容映射 | `lib/infrastructure/database/persistence_compatibility.dart`、`lib/infrastructure/repositories/mappers/compression_mode_mapper.dart`、`lib/infrastructure/repositories/mappers/media_task_config_json_mapper.dart` |
| 媒体类型识别 | `FileExtensionMediaKindResolver` |
| 专有音频输入适配 | `DefaultMediaInputPreparer`、`ProprietaryAudioDecoderDispatcher`、`NativeNcmAudioDecoder`、`BundledProprietaryAudioAdapterRegistry` |
| FEngine Gateway | `EngineGateway`、`EngineMediaGateway`、`LocalFEngineGateway` |
| 媒体分析 | `SubmitEngineAnalysisBatchUseCase` 原子提交 FEngine，`EngineLifecycleCoordinator` 投影队列与终态，`EngineAnalysisProjectionRepository` 保存 FLL Snapshot |
| 队列与执行控制 | `MediaTaskExecutionCoordinator`、Engine Snapshot 对账和 FEngine lifecycle commands |
| 预览帧 | `GeneratePreviewFramesUseCase` 经 `EngineMediaGateway` 获取 FLL artifact |
| 视频缩略图 | `WorkbenchTaskThumbnailStore` 经 `EngineMediaGateway` 获取并缓存 FLL artifact |

## 测试与验证边界

自动化测试入口：

```bash
flutter analyze
flutter test
```

当前测试重点：

- FLL Snapshot document 解析和配置 selection 映射。
- FEngine Gateway 命令 payload、事件和错误映射。
- 队列启动、多个活动 execution、暂停、恢复、取消、双 revision 重排和按资源池 LIFO 抢占恢复。
- 预览帧与缩略图 Control queue 请求、artifact 映射和 Client 缓存去重。
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
- 应用设置通过 `/settings` 全屏路由打开，按应用、关于、视频、图片、音频和输出分区独立保存或取消。
- `build/dependencies/ffmpeg/*` 保存被忽略的 static libav SDK 构建输入；Desktop package 不复制其中的 CLI executable。
- bundled static libav 的来源、构建信息与法律资料仍需随发布材料保持可追溯，见 `docs/reference/ffmpeg-license-distribution.md`。
