# FrameLean Desktop Client

`desktop-client` 是用户直接使用的 FrameLean 桌面产品客户端，当前使用 Flutter 实现并面向 macOS 和 Windows。它负责用户交互、本地产品状态与持久化、任务操作、平台集成和结果展示。产品介绍、下载与安装说明见 [FrameLean 项目主页](../README.md)。

## 主要职责

- 提供媒体导入、任务配置、执行控制、结果展示和应用设置界面。
- 管理本地任务状态、用户设置以及 Drift / SQLite 持久化数据。
- 调用 FFmpeg / FFprobe 完成媒体分析和处理，并处理本地文件与进程生命周期。
- 集成 macOS 和 Windows 的窗口、通知、文件选择、更新与安装相关能力。

当前客户端仍直接管理 FFmpeg / FFprobe 进程和本地执行队列；与 FEngine 的通信及执行职责迁移尚未完成。

## 平台边界

- macOS Universal 2：支持 Intel x86_64 和 Apple Silicon arm64。
- Windows x64：支持安装版和便携版构建。
- Linux 与 Web 不在当前支持范围内，仓库不保留对应平台工程。

## 开发

```bash
flutter pub get
flutter run -d macos
flutter analyze
flutter test
```

Windows 开发时将设备参数改为 `windows`。

## 文档

- [客户端项目上下文](CONTEXT.md)
- [客户端文档入口](docs/README.md)
- [架构说明](docs/develop/architecture.md)
- [测试计划](docs/develop/test-plan.md)
- [正式发布记录](../docs/releases/desktop-client/)
- [仓库级构建与发布脚本](../scripts/README.md)

## 许可

FrameLean Desktop Client 按根目录的 [GPL-3.0-or-later](../LICENSE) 分发。
