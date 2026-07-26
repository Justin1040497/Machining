# FrameLean 项目上下文

## 项目定位

FrameLean（帧轻）是面向 macOS 和 Windows 的本地桌面媒体压缩与格式处理工具。它以 Flutter Desktop 提供图形界面，通过 FEngine/FLL 执行新的媒体分析与执行生命周期，并使用 Riverpod、Drift 和 SQLite 管理任务、设置、请求身份、引擎投影与队列 revision。旧 FFmpeg/FFprobe 客户端服务仍保留给预览和未迁移兼容功能。

项目不提供云端转码、账号体系、多设备同步、在线转换、音乐平台下载或远程解析服务。

## 当前版本

应用版本以 `pubspec.yaml` 为准，当前为 `1.2.1+8`。`v1.2.1` 已发布，集中交付更新入口、任务夹批量工作流、受控并行、隐藏 partial 输出保护、媒体可靠性、通知策略、快捷键、关闭到后台，以及工作台背景引导。

各版本的稳定事实和正式发布记录见根 `docs/releases/desktop-client/`，开发过程与技术变化见根 `changelog/desktop-client.md`。

## 当前能力

- 视频、图片和音频共享本地任务模型，任务状态覆盖 `await_analysis → analysis_queued → analyzing → ready → execution_queued → running → terminal`。
- 一次导入先在 Drift 事务中组织任务夹，再按稳定顺序摊平成独立 FEngine 分析任务；任务夹不进入 FEngine/FLL 模型。
- 工作台投影 FEngine 的真实分析队列位置、执行队列位置、抢占关系和恢复深度；拖拽以双 revision 原子重排等待项。
- 执行为 FLL 单 lane，支持用户暂停/恢复/取消和安全点 LIFO 抢占恢复；输出先写同目录临时文件，成功后原子发布。
- Client 持久化稳定 analysis/execution request ID、Engine identity、queue revision 和事件 sequence；本地 Gateway 使用随机 token 认证的 loopback 守护连接，使 Worker 在 Client 连接中断或进程重启时继续运行。重连后以同一 session 的 Engine Snapshot 对账；离线期间产生的分析/执行终态通过有界终态摘要恢复，不伪造进度。
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
- `infrastructure` 实现数据库、FEngine transport/gateway、兼容 FFmpeg / FFprobe、文件系统、进程和平台能力。
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
