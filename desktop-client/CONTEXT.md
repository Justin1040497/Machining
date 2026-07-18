# FrameLean 项目上下文

## 项目定位

FrameLean（帧轻）是面向 macOS 和 Windows 的本地桌面媒体压缩与格式处理工具。它以 Flutter Desktop 提供图形界面，通过 FFmpeg / FFprobe 完成视频、图片和音频分析与处理，并使用 Riverpod、Drift 和 SQLite 管理任务、设置与本地状态。

项目不提供云端转码、账号体系、多设备同步、在线转换、音乐平台下载或远程解析服务。

## 当前版本

应用版本以 `pubspec.yaml` 为准，当前为 `1.2.1+8`。`v1.2.1` 已发布，集中交付更新入口、任务夹批量工作流、受控并行、隐藏 partial 输出保护、媒体可靠性、通知策略、快捷键、关闭到后台，以及工作台背景引导。

各版本的稳定事实和正式发布记录见根 `docs/releases/desktop-client/`，开发过程与技术变化见根 `changelog/desktop-client.md`。

## 当前能力

- 视频、图片和音频共享本地任务模型，支持文件 / 文件夹导入、FFprobe 分析、类型化配置、任务队列和 FFmpeg 输出。
- 工作台支持任务夹、拖拽排序、批量配置与执行、单任务控制、聚合日志、深浅主题和非阻塞背景引导。
- 执行队列按用户上限与资源守卫受控并行；运行输出先写同目录隐藏 partial，成功后再原子发布。
- 视频覆盖 MP4、MOV、MKV、WebM 和 AVI 的受约束容器 / 编码组合；透明视频自动使用 MOV + ProRes 4444 保留 alpha。
- 图片与音频压缩执行结果验收，避免把无效或更大的输出静默标记为成功。
- 设置保存媒体默认值、输出规则、通知策略、快捷键、并发上限、扫描深度、主题和关闭行为。
- 更新体验提供工作台状态、轻量通知和完整版本日志。公开发布默认跳转 GitHub、Gitee 或备用下载地址，不直接下载安装包。

更细的行为、数据字段和测试边界分别以 `docs/develop/architecture.md`、`docs/develop/data-model.md` 和 `docs/develop/test-plan.md` 为准。

## 架构边界

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

- `domain` 保存实体、枚举和值对象，不依赖 Flutter、Drift、FFmpeg、文件系统或平台 API。
- `application` 保存用例、仓储接口、服务抽象和应用流程。
- `infrastructure` 实现数据库、FFmpeg / FFprobe、文件系统、进程和平台能力。
- `features` 负责功能 UI 与 Riverpod 状态协调。
- `app` 负责入口、主题、路由、依赖装配和跨功能展示组件。

## 平台与发布边界

| 平台 | 当前边界 |
| --- | --- |
| macOS Universal 2 | 主要发布平台，单一 DMG 覆盖 Intel 与 Apple Silicon |
| Windows x64 | 主要发布平台，提供当前用户安装器和可选便携 ZIP |
| Linux / Web | 不在当前支持范围内，仓库不保留对应平台工程 |

公开更新默认使用外部下载地址。保留的 package 自更新链只有在服务端没有外部地址且提供完整 package 元数据时才可能使用，重新启用前需单独验证签名、下载和安装。更新服务端位于 Monorepo 的 `backend/`；客户端与服务端仍保持各自职责边界。

## 文档入口

- 文档地图：`docs/README.md`
- 当前工作：`docs/work/active.md`
- 有效决策：`docs/work/decisions.md`
- 工程事实：`docs/develop/`
- 版本事实：根 `docs/releases/desktop-client/`
- 项目 Skills：`.agents/skills/README.md`
