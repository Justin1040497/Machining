# Architecture

FrameLean Monorepo 包含四个主要组件：`desktop-client` 是用户直接使用的桌面产品客户端，`backend` 提供更新服务与管理后台，`fll`（FrameLean Lib）是进程内核心处理库和 Runtime Schema 代码源头，`fengine`（FrameLean Engine）是依赖 FLL 的独立引擎进程、执行宿主和进程级管理边界。

FLL 拥有媒体模型、分析、环境与能力发现、配置决策、Processor、Pipeline、Plugin、进程内 Task、Scheduler、Runtime 和 Runtime Schema。FEngine 负责装配 FLL，并在后续真实实现中承接引擎进程生命周期、运行隔离、外部请求入口及状态、进度、日志、错误和结果的进程级边界；它不接管 FLL 的核心处理逻辑。

`fengine` 是独立 Cargo 工程，通过本地 path 依赖使用实际需要的 `fll` crates，不是 `fll` workspace member。当前 FEngine 只有 CLI Bootstrap，尚未实现常驻服务、IPC、父进程监控、会话管理或完整执行宿主。Desktop Client 因此仍直接运行 FFmpeg / FFprobe 并管理本地队列。Backend 内部模块以 `backend/pom.xml` 为唯一事实来源。
