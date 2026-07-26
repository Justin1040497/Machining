# FLL (FrameLean Lib)

FLL 是 FrameLean 的核心处理库。它提供媒体模型与分析、机器环境与能力发现、Backend 能力事实、配置决策、Processor、Pipeline、Plugin、进程内任务执行 Runtime 和 Runtime Schema；FFmpeg 仅作为进程内 native media libraries 使用。

FLL 拥有进程内处理逻辑、Task 状态、Scheduler 和执行组合，不负责桌面 UI、跨进程通信或操作系统级引擎进程宿主管理。后者属于独立 FEngine 的进程级边界。

## 当前阶段

当前版本在 `v0.1.0 Architecture Foundation` 上提供：

- 九个库 crate 组成的 Rust Workspace。
- 与 FFmpeg 无关的媒体和 Processor 抽象。
- 视频、音频、图片和动图的类型化媒体分析模型。
- 通过 libavformat/libavcodec/libavutil 进行的进程内媒体探测。
- 静态机器环境和动态资源采样。
- Demuxer、Decoder、Processor、Encoder、Muxer 的中立能力契约。
- Native 支持、Engine 注册和完整执行 readiness 的分离。
- 从完整媒体事实生成 `InputMediaRequirements`，并与静态环境、Backend 明确约束和 execution readiness 求交。
- 原子 `ExecutionChainCandidate`、由 Candidate 派生的配置选项图、同链 Recommendation、四个完整产品 Preset、显式 Candidate 选择与 `ResolvedConfiguration`。
- Runtime 聚合响应、BLAKE3 `SourceFingerprint`、UUID v4 `AnalysisId`、可查询及可序列化恢复的 AnalysisSnapshot、有效性检查和原子 revision 校验。
- 配置解析只使用 Snapshot 冻结的需求、候选、选项图、推荐、预设和估算策略；Snapshot 同时记录 decision/estimator model revision，不兼容的 Runtime 会拒绝重新解析。
- 低置信度基线体积估算与已校准目标体积策略的分离；未校准策略不能反推目标码率。
- 执行提交请求/结果、输出冲突策略和同目录原子发布的 `OutputTransaction`。
- 单活动 execution lane、用户暂停、安全检查点、取消、LIFO 抢占恢复和权威 lane Snapshot。
- 基于进程内 libavformat 的真实 packet stream-copy/remux Backend，包含进度、回滚和原子输出发布。
- 同一处理阶段内的最小 Pipeline 执行骨架。
- 静态 Plugin、ProcessorFactory 和 Registry。
- Task 生命周期、分析 FIFO 与执行 LIFO 调度、Runtime 组装入口。

现有 CLI 已迁入独立的 `../fengine` 工程，不属于本 workspace。

当前版本可以分析媒体、生成冻结 Snapshot、创建真实 execution，并对不含 Decoder、Encoder 或 Processor 的候选链执行 libav packet stream-copy/remux。执行进度、用户暂停/恢复、取消、安全抢占、LIFO 自动恢复与 `OutputTransaction` 已接入 Runtime。需要任一转换节点的链仍返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`，不会被 native discovery 伪装为 Engine-ready。当前不提供完整压缩/转码、动态插件加载、IPC 或网络服务。

## Workspace

| Crate | 职责 |
| --- | --- |
| `framelean-core` | ID、统一错误和基础结果类型 |
| `framelean-media` | 媒体模型与 Processor API |
| `framelean-analysis` | 纯媒体分析领域与 Analyzer 抽象 |
| `framelean-environment` | 静态环境快照与动态资源监控 |
| `framelean-decision` | Capability、Recommendation、Preset 与 Estimator |
| `framelean-ffmpeg` | libav native Adapter 与 Backend 事实 |
| `framelean-pipeline` | Node 边界、Pipeline 构建与顺序执行 |
| `framelean-plugin` | 静态 Plugin、Factory 和 Registry |
| `framelean-runtime` | Task、Scheduler 和 composition root |

## 运行与验证

```bash
cargo check --workspace --all-targets
cargo test --workspace
```

`demo` 使用验证专用 Passthrough Processor 演示静态 `Plugin -> Factory -> Processor -> Pipeline -> Runtime -> Completed Task` 链路，不执行真实媒体处理。

当前 `framelean-ffmpeg` 开发构建使用系统 FFmpeg headers/libraries；本机已验证 Homebrew libavformat/libavcodec/libavutil。三平台 bundled libraries、预生成 bindings 和发布 ABI 尚未完成 qualification，不能视为发布事实。

Runtime Schema 的 Rust 类型和导出逻辑位于 `crates/framelean-runtime`，生成基线位于 `schemas`，导出 example 与一致性测试继续保留在本 workspace。

## License

FrameLean 主许可证见仓库根 `LICENSE`。
