# FrameLean（帧轻）

[![Platform](https://img.shields.io/badge/platform-macOS%20Universal%202%20%7C%20Windows%20x64-000000)](#平台范围)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)](#项目结构)
[![FFmpeg](https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808)](#ffmpeg--ffprobe-运行时)
[![License](https://img.shields.io/badge/license-GPLv3%2B-C62828)](#许可说明)

FrameLean（帧轻）是一个本地桌面媒体压缩与格式处理工具，基于 Flutter、FFmpeg / FFprobe、Riverpod等技术构建。可以处理常用的视频、图片、音频等媒体任务，对齐进行压缩、格式转换，让用户不用手写 FFmpeg 命令也能处理本地媒体文件。

FrameLean 当前仍以视频压缩链路最完整：导入视频，分析源文件信息，选择推荐方案或自定义目标体积，配置编码、分辨率和输出格式，然后执行 FFmpeg 任务。图片和音频已进入同一任务模型，支持导入、分析、分类型配置、基础输出处理、任务夹批量管理和完成结果展示。

完整变更记录见 [CHANGELOG.md](CHANGELOG.md)。

## 产品截图

<table>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed00daf1.png" alt="工作台页面" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed031349.png" alt="任务详情设置" width="100%"></td>
</tr>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7eced7133.png" alt="应用设置页面" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed04b5e7.png" alt="通知中心页面" width="100%"></td>
</tr>
</table>

## 平台范围

当前主要支持和验证的平台：

- macOS 10.15+（Intel x86_64 与 Apple Silicon arm64）
- Windows x64

当前发布和运行时打包说明以 macOS Universal 2 和 Windows x64 为准。

## 功能

- 拖拽或选择导入本地视频、图片、音频和部分专有音频输入文件。
- 使用 FFprobe 分析媒体信息：视频时长、分辨率、编码、码率、色彩信息；图片尺寸、编码和像素信息；音频时长、编码、声道、采样率和码率。
- 三种类型的媒体任务都支持保留元数据
- 支持识别的媒体格式：
  - 19 种视频格式（MP4、MOV、MKV、AVI、WEBM、M4V、FLV、WMV、MPG/MPEG、TS、M2TS/MTS、3GP/3G2、VOB、OGV、DV、ASF）
  - 13 种图片格式（JPG/JPEG、PNG、WebP、GIF、BMP、TIF/TIFF、HEIC/HEIF、AVIF、ICO、TGA）
  - 20 种音频格式（MP3、WAV、AAC、FLAC、M4A、OGG/OGA、Opus、WEBM、AIFF/AIF/AIFC、WMA、AMR、APE、ALAC、CAF、AU、WV、TTA），以及 NCM、MGG、MFLAC 等专有音频格式。

- 视频任务支持缩略图、预览帧、推荐方案、自定义目标体积、输出封装（MP4 / MOV / MKV / WebM / AVI）、视频编码（H.264 / HEVC / VP9 / AV1 / ProRes / MPEG-4 Part 2 / MJPEG）、编码处理器（libx264 / libx265 / libvpx-vp9 / libsvtav1 / prores_ks / VideoToolbox / NVENC / QSV / AMF）和分辨率配置（保持原始 / 2160p / 1080p / 720p / 480p）。
- 图片任务支持输出格式、分辨率、质量，支持 JPEG、PNG、WebP、BMP、TIFF、GIF 等输出方向。
- 音频任务支持输出格式、码率、采样率、声道，支持 MP3、M4A/AAC、WAV、FLAC、AIFF、WMA、Opus、Ogg Opus 等输出方向。
- NCM 输入使用本地 Dart 解密适配；MGG、MFLAC 等 QMC 变体通过外部适配器或直接放置的 `qmc-decrypt` 运行时接入。
- 支持受控并行任务队列，底部开始会按总列表顺序连续执行，任务夹开始只执行夹内任务，单任务开始可插队并在执行位满时暂停最早运行者。
- 批量导入会按媒体类型自动创建任务夹；任务和任务夹支持拖拽排序、夹内任务排序、拖入同类型任务夹和从任务夹移回总列表，并将顺序持久化到本地 SQLite。
- 应用重启后从本地 SQLite 恢复任务、设置、默认媒体配置和主题偏好。
- 源文件丢失或变更后提示重新指定或重新分析。
- 内置或自动查找 FFmpeg / FFprobe，并检测当前运行时可用的视频、图片和音频编码器。
- 工作台支持深浅主题切换；启动前读取已保存主题，避免打开后从浅色闪到深色。
- 应用通知中心：工作台右上角统一入口，未读角标、右向左滑入浮层、按类型展示、批量已读和清扫全部通知；通知策略可按事件选择通知、临时通知或不通知。
- 自托管更新客户端已接入主流程：应用启动自动静默检查一次，设置页关于栏可手动检查、下载和重启更新，工作台顶部在存在更新或下载中时保留入口。
- 输出文件名模板：支持 `{source}`、`{date}`、`{action}`、`{codec}`、`{encoder}`、`{version}` 变量，输入框自由编辑，右侧常用模板菜单快速切换。
- 运行中的 FFmpeg 输出先写入同目录隐藏 `.framelean-*.partial.*` 文件，成功后发布到最终路径；取消、失败、异常退出和启动恢复会清理未发布输出。
- HDR10 / HLG 视频自动通过 `zscale + tonemap` 转 SDR；保持 HDR 输出限定为 HEVC Main10，Dolby Vision Profile 5 风险拦截。

## 怎么用

1. 打开 FrameLean，按需进入左下角设置页面配置默认媒体格式、输出路径和通知偏好。
2. 将媒体文件或文件夹拖入窗口，或使用导入按钮选择本地文件和文件夹。
3. 在任务列表中选择任务或任务夹，查看源文件信息、缩略图、媒体摘要或夹级批量配置。
4. 打开任务详情设置，按媒体类型调整配置：
   - 推荐方案选项：选择均衡推荐、微信发送、清晰优先或体积优先。
   - 自定义目标体积：通过比例滑杆选择希望接近的输出体积。
   - 图片任务：配置格式、分辨率、质量和元数据保留。
   - 音频任务：配置格式、码率、采样率和声道。
5. 按需调整输出格式、编码相关选项、输出目录和输出文件名。
6. 点击开始处理，任务进入本地 FFmpeg 队列。
7. 处理完成后，通过任务项尾部入口、临时通知或通知中心打开输出文件所在位置。

如果任务失败，可以查看任务状态、通知中心详情或任务日志后重试。若源文件被移动或删除，应用会将任务标记为源文件丢失，需要重新指定文件。如果你想处理的媒体不被支持，可以提交 Issue 反馈。

## 开发环境

基础要求：

- Flutter / Dart，当前项目使用 Dart SDK `^3.11.0`。
- macOS 开发需要 Xcode Command Line Tools。
- Windows 开发需要 Visual Studio C++ Desktop Build Tools。
- macOS 构建 FFmpeg 运行时需要 Homebrew、`autoconf`、`automake`、`libtool`、`nasm`、`pkg-config`。

安装 Flutter 依赖：

```bash
flutter pub get
```

macOS 安装 FFmpeg 构建依赖：

```bash
brew install autoconf automake libtool nasm pkg-config
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

命令行入口（视频压缩 / 图片处理 / 音频处理）：

```bash
# 视频压缩
dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4
dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 --codec h265 --resolution 1080p
dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 -c av1 -e nvenc --crf 26 -p clear -f mkv
dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 -m targetSize --target-size 50MB
# 批量
dart run tool/framelean_cli.dart compress a.mp4 b.mp4 c.mp4 --codec h265 -r 1080p

# 图片处理
dart run tool/framelean_cli.dart image ~/Pictures/photo.png --format webp --quality 90
dart run tool/framelean_cli.dart image ~/Pictures/photo.png --format jpg --resize longEdge1920 -q 85

# 音频处理
dart run tool/framelean_cli.dart audio ~/Music/song.wav --format mp3 --bitrate k320
dart run tool/framelean_cli.dart audio ~/Music/song.flac --format m4a --bitrate k192 --channels stereo
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

- Application Use Cases 和任务执行入口。
- 应用设置页面、默认媒体配置、主题偏好和 Drift 持久化映射。
- 压缩模式持久化兼容映射。
- 压缩建议和输出体积估算。
- FFmpeg 命令构造。
- FFmpeg 编码器能力检测。
- FFmpeg 进程观测和任务队列执行。
- FFprobe 媒体分析。
- 预览帧和缩略图生成。
- 图片 / 音频任务配置、命令构造和步骤型进度。
- 专有音频输入适配器探测和 NCM / QMC 输入边界。
- 工作台预览状态、任务配置交互、拖拽排序、主题切换、响应式尺寸和统一弹窗风格。

真实 FFmpeg / FFprobe 验证需要平台运行时文件。更完整的测试说明见 [docs/develop/test-plan.md](docs/develop/test-plan.md)。

## 怎么构建

构建前建议先执行：

```bash
flutter pub get
flutter analyze
flutter test
```

### macOS

分别在原生 Apple Silicon 和 Intel Mac 上准备 FFmpeg / FFprobe 架构切片：

```bash
scripts/build/build_ffmpeg_macos_arch.sh arm64
scripts/build/build_ffmpeg_macos_arch.sh x86_64
scripts/build/build_ffmpeg_macos_universal.sh
```

脚本会构建 zimg、FFmpeg 7.1.1、x264、LAME、libwebp、Opus、libvpx 和 SVT-AV1，合并为
Universal 2 运行时，并检查：

- 没有 Homebrew 动态库依赖。
- `ffmpeg` / `ffprobe` 同时包含 `x86_64` 和 `arm64`。
- `libx264`、`libmp3lame`、`libwebp`、`libopus`、`libvpx-vp9`、`libsvtav1`、`prores_ks`、`mpeg4`、`mjpeg` 和常用 muxer 能力可用。

必须存在的运行时路径：

```text
third_party/ffmpeg/macos-universal/ffmpeg
third_party/ffmpeg/macos-universal/ffprobe
```

Release DMG 构建：

```bash
scripts/release/build_dmg_macos.sh
```

脚本会检查并准备 Universal 2 FFmpeg / FFprobe，先构建和扫描整个 app，
再调用 `pubspec.yaml` 中的 `dmg` 打包依赖，并验证 DMG、内置运行时和包内
法律资料。DMG 文件名会读取
`pubspec.yaml` 的语义化版本，不包含 `+build` 后缀。默认生成未签名、未公证
的本地测试 DMG；需要签名或公证时，可把 `dmg` 参数直接传给脚本。

Release app 和 DMG 位置：

```text
build/macos/Build/Products/Release/FrameLean.app
build/macos/Build/Products/Release/FrameLean-v1.2.1.dmg
```

验证 app 内置 FFmpeg 和法律资料：

```bash
APP="build/macos/Build/Products/Release/FrameLean.app"
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -version
"$APP/Contents/Resources/ffmpeg/ffprobe" -hide_banner -version
scripts/release/verify_macos_universal.sh "$APP"
test -f "$APP/Contents/Resources/legal/COPYING"
```

### Windows

Windows 构建前必须准备：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

生成 Windows Release 目录、便携 ZIP 和 Inno Setup 安装器：

```powershell
PowerShell -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1
```

`build_windows.ps1` 是唯一的 Windows 正式发布入口。它只执行一次 Flutter
Release 构建，默认同时生成 ZIP 和安装器，并验证 FFmpeg、FFprobe、Visual C++
Runtime、法律材料和可选 QMC 适配器。特殊场景可以使用 `-SkipZip` 或
`-SkipInstaller` 只生成一种分发产物。

Release 产物位置：

```text
build/windows/x64/runner/Release/
build/windows/x64/runner/FrameLean-v1.2.1-windows-x64.zip
build/windows/x64/installer/FrameLean-v1.2.1-windows-x64-setup.exe
```

Windows CMake 会把运行时复制到：

```text
build/windows/x64/runner/Release/ffmpeg/
```

Windows zip 文件名会读取 `pubspec.yaml` 的语义化版本，解压后顶层目录应为
`FrameLean-v1.2.1-windows-x64/`。如果 `ffmpeg.exe` 或 `ffprobe.exe` 不存在，
Windows Release 构建会失败，避免产出缺少内置运行时的发布包。

发布脚本会从 Visual Studio 的 x64 Redistributable 目录复制
`msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`。找不到这些运行时
时构建直接失败，避免安装器在干净 Windows 机器上安装后无法启动。

GitHub Actions 会额外调用 `scripts\build\build_qmc_decrypt_windows.ps1`，按
锁定 commit 构建 `qmc-decrypt.exe`，再将它及上游许可证装入 ZIP 和安装器。

安装器固定使用当前用户目录
`%LOCALAPPDATA%\Programs\FrameLean`，不提供管理员安装模式，为后续无需 UAC
的静默覆盖更新保持一致的安装权限和路径。

验证 app 内置 FFmpeg：

```powershell
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -version
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe -hide_banner -version
```

全部脚本职责见 `scripts/README.md`。

## FFmpeg / FFprobe 运行时

FrameLean 解析运行时时的优先级：

1. 用户自定义路径。
2. 应用包内置路径。
3. 常见系统安装路径。
4. 系统 `PATH`。

仓库预留的内置运行时位置：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
third_party/ffmpeg/macos-x64/ffmpeg
third_party/ffmpeg/macos-x64/ffprobe
third_party/ffmpeg/macos-universal/ffmpeg
third_party/ffmpeg/macos-universal/ffprobe
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

这些二进制文件不提交到 Git。仓库只保留目录说明、构建脚本和构建信息。

macOS Release app 内的运行时位置：

```text
FrameLean.app/Contents/Resources/ffmpeg/
```

Windows Release 目录内的运行时位置：

```text
FrameLean.exe 同级目录/ffmpeg/
```

## GPU 编码加速

FrameLean 会执行：

```bash
ffmpeg -hide_banner -encoders
```

并根据输出判断当前 FFmpeg 支持哪些硬件编码器。任务配置为“自动选择”时，会优先使用可用的 GPU 编码器；如果当前电脑或 FFmpeg 不支持对应编码器，会回退到 CPU 编码。

macOS 自动选择优先级：

```text
VideoToolbox -> libx264 / libx265 / libvpx-vp9 / libsvtav1 / prores_ks / mpeg4 / mjpeg
```

HDR / HVC1 / 10-bit 等高危源优先使用软件编码，显式选择 VideoToolbox 时仍尊重用户选择。

Windows 自动选择优先级：

```text
NVIDIA NVENC -> Intel Quick Sync -> AMD AMF -> libx264 / libx265 / libvpx-vp9 / libsvtav1 / prores_ks / mpeg4 / mjpeg
```

## 项目结构

项目采用接近 Clean Architecture 的分层结构，让 UI、业务规则、数据存储和 FFmpeg 进程调用分开。

```text
lib/
  app/                 应用入口、路由和全局配置
  domain/              实体、枚举和值对象
  application/         仓储接口、Use Cases、输入运行时、命令规划和执行服务抽象
  infrastructure/      Drift 数据库、provider 装配、仓储实现、FFmpeg / FFprobe、本地文件和进程实现
  features/workbench/  工作台页面、状态入口、弹窗、覆盖层、表单控件和任务列表组件
```

核心流程：

```text
导入文件
  -> 校验媒体类型和源文件指纹
  -> 创建 MediaTask 并保存到 SQLite
  -> FFprobe 分析媒体信息
  -> 生成缩略图和预览素材
  -> 根据任务配置构造 FFmpeg 命令
  -> 输出 preflight 创建隐藏 partial 并改写执行输出路径
  -> 队列启动 FFmpeg 进程
  -> 解析进度并写回任务状态
  -> 完成后发布到最终路径并记录结果，失败或取消时清理未发布输出
```

更多架构说明见 [docs/develop/architecture.md](docs/develop/architecture.md)。

## 文档

项目背景和当前上下文见 [CONTEXT.md](CONTEXT.md)，文档入口在 [docs/README.md](docs/README.md)。

常用文档：

- [docs/work/active.md](docs/work/active.md)：当前正在推进的任务。
- [docs/work/backlog.md](docs/work/backlog.md)：候选任务池。
- [docs/work/decisions.md](docs/work/decisions.md)：仍有效的重要决策索引。
- [docs/releases/v1.2.1/release.md](docs/releases/v1.2.1/release.md)：当前发布说明。
- [docs/develop/architecture.md](docs/develop/architecture.md)：项目架构和模块边界。
- [docs/develop/technology-stack.md](docs/develop/technology-stack.md)：技术栈、依赖和平台范围。
- [docs/develop/data-model.md](docs/develop/data-model.md)：数据库 schema、任务模型和设置模型。
- [docs/develop/test-plan.md](docs/develop/test-plan.md)：自动化测试和手动验证计划。
- [docs/develop/workflow.md](docs/develop/workflow.md)：需求、分支、测试、实现、验证、提交、PR 和发布流程。
- [.agents/skills/README.md](.agents/skills/README.md)：FrameLean 项目级 skills 路由和共享预读协议。
- [docs/lessons.md](docs/lessons.md)：踩坑记录和经验总结。
- [docs/reference/ffmpeg-license-distribution.md](docs/reference/ffmpeg-license-distribution.md)：FFmpeg、x264、LAME、libwebp、Opus、GPL 路线和分发参考。

## 许可说明

FrameLean 项目整体按 `GPL-3.0-or-later` 分发。根目录保留 `LICENSE` 作为标准发现入口，完整发布法律资料集中在 `legal/`：

- [LICENSE](LICENSE)：GNU General Public License v3 正文。
- [legal/NOTICE.md](legal/NOTICE.md)：项目版权、无担保和运行时声明。
- [legal/COPYING](legal/COPYING)：项目 GPLv3+ 分发入口说明。
- [legal/THIRD_PARTY_NOTICES.md](legal/THIRD_PARTY_NOTICES.md)：FFmpeg、x264、LAME、libwebp、Opus、libvpx、SVT-AV1、Flutter/Dart 依赖声明。
- [legal/SOURCE_OFFER.md](legal/SOURCE_OFFER.md)：源码可得性和 FFmpeg 构建信息。
- [legal/third-party/](legal/third-party)：第三方运行时和依赖资料。

项目当前内置 FFmpeg + x264 + LAME + libwebp + Opus + libvpx + SVT-AV1 构建路线。包含该运行时的发布包需要遵守对应 FFmpeg 构建的 GPLv3+ 许可要求。FFmpeg、x264、LAME、libwebp、Opus、libvpx、SVT-AV1 等依赖归各自原项目维护，FrameLean 只调用并随应用分发相应运行时。

详细说明见 [docs/reference/ffmpeg-license-distribution.md](docs/reference/ffmpeg-license-distribution.md)。
