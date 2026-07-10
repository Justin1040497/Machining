# FrameLean（帧轻）

[![Platform](https://img.shields.io/badge/platform-macOS%20Universal%202%20%7C%20Windows%20x64-000000)](#下载与安装)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)](https://flutter.dev/)
[![FFmpeg](https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808)](https://ffmpeg.org/)
[![License](https://img.shields.io/badge/license-GPLv3%2B-C62828)](LICENSE)

FrameLean 是一款面向 macOS 和 Windows 的本地媒体压缩与格式处理工具。

无需编写 FFmpeg 命令，即可处理视频、图片和音频，支持单文件操作、批量任务、任务夹管理、硬件编码加速和自定义输出设置。媒体处理在本机完成，不会上传你的源文件。

- 项目主页：<https://github.com/zhouycheng/FrameLean>
- 下载版本：<https://github.com/zhouycheng/FrameLean/releases>
- 问题反馈：<https://github.com/zhouycheng/FrameLean/issues>
- 完整变更记录：[CHANGELOG.md](CHANGELOG.md)

## 界面预览

<table>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed00daf1.png" alt="FrameLean 工作台" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed031349.png" alt="FrameLean 任务设置" width="100%"></td>
</tr>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7eced7133.png" alt="FrameLean 应用设置" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/06/14/6a2e7ed04b5e7.png" alt="FrameLean 通知中心" width="100%"></td>
</tr>
</table>

## 主要功能

### 视频

- 视频压缩、格式转换和目标体积控制。
- 支持 MP4、MOV、MKV、WebM、AVI 等常用封装格式。
- 支持 H.264、HEVC、VP9、AV1、ProRes、MPEG-4 Part 2、MJPEG。
- 支持保持原始分辨率，或输出 2160p、1080p、720p、480p。
- 自动检测 VideoToolbox、NVENC、QSV、AMF 等硬件编码能力。
- 支持 HDR10 / HLG 转 SDR，并对高风险 Dolby Vision 输入进行提示或拦截。

### 图片

- 支持 JPEG、PNG、WebP、BMP、TIFF、GIF 等常用格式。
- 可调整输出格式、尺寸、质量和元数据保留策略。
- 支持图片批量处理。

### 音频

- 支持 MP3、M4A / AAC、WAV、FLAC、AIFF、WMA、Opus、Ogg Opus 等输出格式。
- 可调整码率、采样率和声道。
- 支持 NCM，以及通过适配器处理 MGG、MFLAC 等部分专有音频格式。

### 批量任务与工作流

- 支持拖入文件或文件夹。
- 按媒体类型自动组织任务夹。
- 支持任务排序、拖入任务夹、移出任务夹和批量配置。
- 支持受控并行队列、暂停、重试和任务恢复。
- 使用本地 SQLite 保存任务、设置、主题和默认媒体配置。
- 输出先写入临时文件，成功后再发布到最终路径，降低异常退出造成的损坏风险。

## 支持平台

| 平台 | 支持范围 |
|---|---|
| macOS | 10.15 及以上，Intel x86_64 与 Apple Silicon arm64，Universal 2 |
| Windows | Windows x64 |

## 下载与安装

请从 [GitHub Releases](https://github.com/zhouycheng/FrameLean/releases) 下载最新版本。

### macOS

下载 DMG 后，将 `FrameLean.app` 拖入“应用程序”。

> **当前 macOS 安装包尚未经过 Apple Developer ID 签名和公证。**
>
> 首次打开时，macOS 可能提示“Apple 无法验证 FrameLean 是否包含恶意软件”。这是因为安装包没有 Apple 公证票据，并不代表系统已经检测到恶意代码。

首次打开如被系统阻止：

1. 将 `FrameLean.app` 拖入“应用程序”。
2. 尝试打开一次 FrameLean。
3. 打开“系统设置”。
4. 进入“隐私与安全性”。
5. 找到 FrameLean 的安全提示，点击“仍要打开”。
6. 根据系统提示再次确认。

### Windows

通常提供两种产物：

- `FrameLean-vX.Y.Z-windows-x64-setup.exe`：安装版。
- `FrameLean-vX.Y.Z-windows-x64.zip`：便携版，解压后直接运行。

Windows 安装版默认安装到当前用户目录，不要求管理员权限。

## 快速使用

1. 打开 FrameLean。
2. 拖入媒体文件或文件夹，也可以点击导入按钮选择文件。
3. 在任务列表中选择任务或任务夹。
4. 选择推荐方案，或自定义格式、编码、分辨率、质量、码率和输出位置。
5. 点击“开始处理”。
6. 完成后从任务项、临时通知或通知中心打开输出目录。

任务失败时，可查看任务状态和日志后重试。源文件被移动、删除或发生变化时，FrameLean 会提示重新指定或重新分析。

## 更新检查

FrameLean 启动后会静默检查一次新版本，也可以在“设置 → 关于”中手动检查。

发现新版本时，客户端会展示更新日志，以及 GitHub、Gitee 或备用下载入口。当前阶段由用户跳转到下载页面并手动安装，新版客户端不会直接自动下载 EXE、DMG 或 ZIP 安装包。

## 隐私说明

- 视频、图片和音频处理均在本机完成。
- 源媒体文件不会上传到 FrameLean 服务器。
- 检查更新时，客户端会向更新服务请求最新版本信息。
- 选择外部下载入口后，将使用系统浏览器打开对应页面。

## 常见问题

### 为什么输出文件可能比源文件大？

格式、编码器、质量、分辨率和码率都会影响体积。建议选择“体积优先”方案，或使用自定义目标体积功能。图片和音频任务在输出不符合压缩目标时会给出相应状态提示。

### 为什么没有显示某个硬件编码器？

FrameLean 会根据当前设备、驱动和内置 FFmpeg 的实际能力进行检测。未显示通常表示当前环境不支持该编码器。

### 为什么任务显示源文件丢失？

源文件可能被移动、重命名、删除或发生变化。请在任务中重新指定源文件并重新分析。

### macOS 为什么提示无法验证开发者？

当前 macOS 产物未经过 Apple Developer ID 签名和公证。请按照上方 [macOS 安装说明](#macos) 在“隐私与安全性”中手动允许。

## 开发

<details>
<summary>展开开发与构建说明</summary>
### 环境要求

- Flutter / Dart，项目使用 Dart SDK `^3.11.0`。
- macOS：Xcode Command Line Tools、CocoaPods。
- Windows：Visual Studio C++ Desktop Build Tools。

安装依赖：

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

生成 Drift 代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

静态分析与测试：

```bash
flutter analyze
flutter test
```

构建发布包前，需要准备对应平台的 FFmpeg / FFprobe 运行时：

```text
third_party/ffmpeg/macos-universal/ffmpeg
third_party/ffmpeg/macos-universal/ffprobe
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

macOS DMG：

```bash
scripts/release/build_dmg_macos.sh
```

Windows ZIP 与安装器：

```powershell
PowerShell -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1
```

更完整的开发、测试和发布说明：

- [scripts/README.md](scripts/README.md)
- [docs/develop/architecture.md](docs/develop/architecture.md)
- [docs/develop/test-plan.md](docs/develop/test-plan.md)
- [docs/develop/workflow.md](docs/develop/workflow.md)
- [docs/README.md](docs/README.md)

</details>

## 项目结构

```text
lib/
  app/                 应用入口、路由和全局配置
  domain/              实体、枚举和值对象
  application/         用例、仓储接口、任务规划和服务抽象
  infrastructure/      数据库、仓储实现、FFmpeg / FFprobe 和系统能力
  features/            工作台、设置、通知等功能界面
```

FrameLean 采用接近 Clean Architecture 的分层结构。详细说明见 [项目架构文档](docs/develop/architecture.md)。

## 许可

FrameLean 按 `GPL-3.0-or-later` 分发，详见 [LICENSE](LICENSE)。

发布包包含 FFmpeg 及部分第三方编解码组件。第三方许可、源码可得性和分发说明见：

- [legal/NOTICE.md](legal/NOTICE.md)
- [legal/THIRD_PARTY_NOTICES.md](legal/THIRD_PARTY_NOTICES.md)
- [legal/SOURCE_OFFER.md](legal/SOURCE_OFFER.md)
- [docs/reference/ffmpeg-license-distribution.md](docs/reference/ffmpeg-license-distribution.md)

FFmpeg、Flutter、Dart 及其他第三方组件的商标和版权归各自权利人所有。
