<p align="center"><strong>FrameLean 是一款面向 macOS 和 Windows 的本地媒体压缩和格式处理工具</strong></p>

<table>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5777c7ac758.png" alt="FrameLean 工作台" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5777c7cb467.png" alt="FrameLean 任务设置" width="100%"></td>
</tr>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5777c85dd78.png" alt="FrameLean 通知中心" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5777c7e3cfa.png" alt="FrameLean 应用设置" width="100%"></td>
</tr>
</table>
<p>
  <a href="#下载与安装"><img src="https://img.shields.io/badge/platform-macOS%20Universal%202%20%7C%20Windows%20x64-000000" alt="Platform"></a>
  <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/built%20with-Flutter-02569B" alt="Flutter"></a>
  <a href="https://ffmpeg.org/"><img src="https://img.shields.io/badge/media%20runtime-FFmpeg%207.1.1-007808" alt="FFmpeg"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3%2B-C62828" alt="License"></a>
  <br>
  <a href="https://github.com/zhouycheng/FrameLean/releases">下载最新版本</a> ·
  <a href="CHANGELOG.md">查看变更记录</a> ·
  <a href="https://github.com/zhouycheng/FrameLean/issues">问题反馈</a> ·
  <a href="docs/README.md">项目文档</a>
</p>


## 核心能力

- 处理视频、图片和音频，支持压缩与格式转换。
- 导入单个文件、多个文件或文件夹，并按媒体类型组织任务夹。
- 自定义容器、编码器、分辨率、质量、码率、声道和输出位置。
- 按设备能力使用 VideoToolbox、NVENC、QSV、AMF 等硬件编码。
- 使用受控并行队列，支持排序、暂停、重试、恢复和批量配置。
- 通过临时输出、结果验收和本地持久化降低任务失败或异常退出造成的损坏风险。

更完整的能力和平台边界见 [项目上下文](CONTEXT.md)。

## 下载与安装

从 [GitHub Releases](https://github.com/zhouycheng/FrameLean/releases) 下载：

- **macOS 10.15+**：Universal 2 DMG，同时支持 Intel x86_64 和 Apple Silicon arm64。
- **Windows x64**：推荐安装版，也提供可选便携 ZIP。

### macOS 首次打开

当前 macOS 安装包尚未经过 Apple Developer ID 签名和公证，因此首次运行可能被系统拦截。将应用拖入“应用程序”并尝试打开一次后，前往“系统设置 → 隐私与安全性”，在 FrameLean 提示处选择“仍要打开”。

<table>
<tr>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5779e6da502.png" alt="macOS 首次打开步骤 1" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5779e76de01.png" alt="macOS 首次打开步骤 2" width="100%"></td>
  <td><img src="https://www.helloimg.com/i/2026/07/15/6a5779e7afb3f.png" alt="macOS 首次打开步骤 3" width="100%"></td>
</tr>
</table>

## 开发

```bash
flutter pub get
flutter run -d macos
flutter analyze
flutter test
```

Windows 开发时将设备参数改为 `windows`。构建、架构、测试和发布规则见：

- [项目文档入口](docs/README.md)
- [架构说明](docs/develop/architecture.md)
- [开发工作流](docs/develop/workflow.md)
- [构建与发布脚本](scripts/README.md)

## 许可

FrameLean 按 [GPL-3.0-or-later](LICENSE) 分发。发布包包含 FFmpeg 及其他第三方组件，相关许可和源码可得性说明见：

- [第三方声明](legal/THIRD_PARTY_NOTICES.md)
- [源码提供说明](legal/SOURCE_OFFER.md)
- [FFmpeg 分发说明](docs/reference/ffmpeg-license-distribution.md)

FFmpeg、Flutter、Dart 及其他第三方组件的商标和版权归各自权利人所有。
