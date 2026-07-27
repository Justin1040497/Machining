# FrameLean Desktop Client

`desktop-client` 是用户直接使用的 FrameLean 桌面产品客户端，当前使用 Flutter 实现并面向 macOS 和 Windows。它负责用户交互、本地产品状态与持久化、任务操作、平台集成和结果展示。产品介绍、下载与安装说明见 [FrameLean 项目主页](../README.md)。

## 主要职责

- 提供媒体导入、任务配置、执行控制、结果展示和应用设置界面。
- 管理本地任务状态、用户设置以及 Drift / SQLite 持久化数据。
- 通过 FEngine Gateway 提交媒体分析与执行，投影引擎队列、进度、抢占关系和终态。
- 集成 macOS 和 Windows 的窗口、通知、文件选择、更新与安装相关能力。

全部媒体路径已统一经 FEngine：Client 任务夹先摊平为独立任务，分析与执行队列分开投影，拖拽使用双 revision 原子重排，单任务开始可转换为安全点 LIFO 抢占。本地 Gateway 通过随机 token 认证的 loopback 守护连接接入 Worker；普通 Client 关闭只断开连接，显式退出会先取消任务再关闭 Worker。媒体元数据来自 FLL `AnalysisSnapshot`，预览帧和视频缩略图由 FLL 进程内 libav helper 生成并通过 FEngine Control queue 返回。Client 不定位、分发或启动 `ffmpeg` / `ffprobe` 可执行文件。

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
