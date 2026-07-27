# Desktop Client 架构

## 文档目的

本文描述 Desktop Client 当前真实架构。媒体核心事实以 FLL 为准，进程与协议边界以 FEngine 为准；Client 只负责用户交互、本地持久化和引擎状态投影。

## 架构总览

```text
Flutter UI / Riverpod
        |
        v
application use cases + coordinators
        |
        +--> domain entities / value objects
        |
        +--> repositories --> Drift / SQLite
        |
        +--> EngineGateway --> FEngine Worker --> FLL Runtime --> bundled static libav
```

分层规则：

- `domain`：任务、设置、枚举和值对象；不依赖 Flutter、Drift、文件系统或 native media API。
- `application`：用例、仓储接口、Engine Gateway 契约和流程协调。
- `infrastructure`：Drift、FEngine transport/gateway、文件系统和平台能力实现。
- `features`：工作台、设置页、弹窗、notifier 和 UI 投影。
- `app`：入口、主题、路由、provider 装配和跨功能展示。

## 源码目录

```text
lib/
  app/
    providers/
    presentation/
    theme/
  application/
    models/
    repositories/
    services/
      engine/
      execution/
      input_runtime/
      platform/
    use_cases/
  domain/
    entities/
    enums/
    value_objects/
  infrastructure/
    database/
    repositories/
    services/
      engine/
      execution/
      input_runtime/
      platform/
  features/
    settings/
    workbench/
```

不存在 Client 侧媒体 CLI runtime、FFmpeg 命令规划、FFprobe 分析器或 FFmpeg 进程 runner。

## 核心边界

### Engine Gateway

- `EngineGateway`：握手、分析、Snapshot 查询、执行提交和关闭。
- `EngineMediaGateway`：预览帧和视频缩略图 artifact。
- `EngineLifecycleGateway`：Engine Snapshot、双队列顺序、执行控制和 LIFO 抢占。
- `LocalFEngineGateway`：length-framed JSON、本机 daemon token 认证、request id/sequence 和事件映射。

### FLL Snapshot 投影

`AnalysisCompleted` 直接返回 FLL Snapshot。Client 保存 `EngineAnalysisProjection`，并从其中展示候选、预设、格式、估算和参数。用户选择被序列化为 selection 后原样提交；Client 不重新解析媒体或重建 native 参数。

### Client 任务夹

任务夹只存在于 Client。导入批次中，同类型且数量不少于 2 的任务可形成任务夹；提交分析或执行时按 Client 稳定顺序摊平成独立 Engine work item。Engine 队列从不包含 folder item。

## 主要流程

### 导入与分析

1. Client 扫描用户选择并读取快速源指纹。
2. Drift 事务保存任务、任务夹和顺序。
3. Client 提交独立 `AnalyzeMedia` 请求。
4. FEngine 管理分析队列；FLL 使用进程内 libav 读取媒体事实并生成冻结 Snapshot。
5. Client 消费 `AnalysisCompleted`，保存 Snapshot 投影并进入 `ready`。

### 配置与执行

1. 配置面板展示 Snapshot 声明的选项。
2. 用户点击开始后，Client 提交 selection、analysis id/revision 和输出请求。
3. FLL 拥有单活动 execution lane；FEngine 投影普通等待队列、活动项和 LIFO 恢复栈。
4. 用户点击另一个任务开始时，FEngine 在安全点暂停当前任务并压栈。
5. 插队任务完成后按 LIFO 恢复；用户主动暂停的任务不会自动恢复。
6. FLL 负责同目录临时输出、成功原子发布和失败回滚。

### 预览帧与视频缩略图

- `GeneratePreviewFrames` 和 `GenerateVideoThumbnail` 进入 FEngine Control queue。
- FEngine 校验 source facts 后调用 FLL `framelean-ffmpeg` API。
- FLL 使用 libavcodec 解码、libswscale 转 RGB24，并事务性写入 BMP。
- 缩略图按多个候选时间点跳过黑帧。
- 两类请求不占用分析队列、不进入 execution lane，也不改变 LIFO 栈。
- 预览帧是源媒体解码帧，不表示压缩后转码效果。

### 重连与对账

Client 通过带随机 token 的 loopback daemon transport 连接 Worker。发现 sequence gap 或重新连接时读取 `GetEngineSnapshot`，以 FEngine 的分析队列、execution lane、LIFO 栈、用户暂停集合和有界终态摘要重建 UI。

## Riverpod 装配

主要 provider：

| Provider | 职责 |
| --- | --- |
| `engineGatewayProvider` | 创建并复用 FEngine Gateway |
| `engineLifecycleCoordinatorProvider` | 连接、心跳、重连和 Snapshot 对账 |
| `mediaAnalysisQueueProvider` | Client 批量提交协调；实际队列属于 FEngine |
| `mediaTaskExecutionCoordinatorProvider` | 开始、暂停、取消、任务夹摊平和抢占入口 |
| `mediaTaskListProvider` | 工作台任务投影和用户操作入口 |
| `workbenchPreviewProvider` | 预览帧请求和 UI 状态 |
| `engineAnalysisProjectionRepositoryProvider` | FLL Snapshot Client 投影持久化 |

UI 不直接创建 transport、数据库或文件系统实现。

## 数据持久化边界

Drift 保存：

- 任务、任务夹、排序和用户配置。
- 源文件指纹与 UI 展示所需分析字段。
- FLL Snapshot Client 投影、analysis/execution identity、request id、revision 和 sequence。
- 应用设置、通知和工作台 order revision。

不保存：

- 预览帧和缩略图缓存文件。
- FEngine 进程内媒体上下文与 FLL Scheduler 状态。
- native media 原始诊断输出。

## 平台边界

| 平台 | 当前状态 | 说明 |
| --- | --- | --- |
| macOS Universal 2 | 主要发布平台 | package 携带静态链接 bundled libav 的 Universal `framelean-engine` |
| Windows x64 | 主要发布平台 | package 携带静态链接 bundled libav 的 `framelean-engine.exe` |
| Linux / Web | 不支持发布 | 仓库不保留对应 Flutter 平台工程 |

Desktop package 不包含或启动 `ffmpeg` / `ffprobe` executable。

## 错误与恢复

- 源文件缺失或 source facts 不匹配时拒绝生成新 Snapshot/artifact。
- 协议、Worker 和 FLL engine code 保持结构化边界。
- 预览帧与缩略图失败只影响可选视觉 artifact，不改变任务状态。
- 需要 Decoder、Encoder 或 Processor 的转码链未实现时返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`。
- Client 不以本地计时器、文件日志或进程句柄作为任务权威；FEngine/FLL Snapshot 和事件是唯一来源。

## 验证入口

- `test/local_fengine_gateway_test.dart`
- `test/engine_media_artifact_use_cases_test.dart`
- `test/analyze_media_task_use_case_test.dart`
- `test/submit_engine_execution_use_case_test.dart`
- `test/task_folder_use_cases_test.dart`
- `test/media_task_notifier_test.dart`
- `test/drift_app_settings_repository_test.dart`

完整命令和手动闭环见 `test-plan.md`。
