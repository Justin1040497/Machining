# FLL (FrameLean Lib)

FLL 是 FrameLean 的核心处理库。它提供媒体模型与分析、机器环境与能力发现、Backend 能力事实、配置决策、Processor、Pipeline、Plugin、进程内任务执行 Runtime 和 Runtime Schema；FFmpeg 仅作为进程内 native media libraries 使用。

FLL 拥有进程内处理逻辑、Task 状态、Scheduler 和执行组合，不负责桌面 UI、跨进程通信或操作系统级引擎进程宿主管理。后者属于独立 FEngine 的进程级边界。

## 当前阶段

当前版本在 `v0.1.0 Architecture Foundation` 上提供：

- 九个库 crate 组成的 Rust Workspace。
- 与 FFmpeg 无关的媒体和 Processor 抽象。
- 视频、音频、图片和动图的类型化媒体分析模型。
- 通过 libavformat/libavcodec/libavutil 进行的进程内媒体探测。
- 通过 libavformat/libavcodec/libswscale 进行的预览帧解码、BMP artifact 输出和非黑帧视频缩略图选择。
- 静态机器环境和动态资源采样。
- Demuxer、Decoder、Processor、Encoder、Muxer 的中立能力契约。
- Native 支持、Engine 注册和完整执行 readiness 的分离。
- 从完整媒体事实生成 `InputMediaRequirements`，并与静态环境、Backend 明确约束和 execution readiness 求交。
- 原子 `ExecutionChainCandidate`、由 Candidate 派生的配置选项图、同链 Recommendation、四个完整产品 Preset、显式 Candidate 选择与 `ResolvedConfiguration`。
- Runtime 聚合响应、BLAKE3 `SourceFingerprint`、UUID v4 `AnalysisId`、可查询及可序列化恢复的 AnalysisSnapshot、有效性检查和原子 revision 校验。
- 配置解析只使用 Snapshot 冻结的需求、候选、选项图、推荐、预设和估算策略；Snapshot 同时记录 decision/estimator model revision，不兼容的 Runtime 会拒绝重新解析。
- 低置信度基线体积估算与已校准目标体积策略的分离；未校准策略不能反推目标码率。
- 执行提交请求/结果、输出冲突策略和同目录原子发布的 `OutputTransaction`。
- Video 1 槽与 Auxiliary 动态 1/2 槽、用户暂停、安全检查点、取消、按池 LIFO 抢占恢复和权威 execution Snapshot。
- 基于进程内 libavformat 的真实 packet stream-copy/remux Backend，包含进度、回滚和原子输出发布。
- 真实单视频、无音频的 decode -> 可选 swscale 像素格式转换 -> libx264 encode -> MP4 mux 执行链。
- 由冻结 Snapshot 的 Candidate 构建并校验完整跨阶段 `MediaPipelinePlan`，再由 Runtime 选择 native execution Backend。
- 静态 Plugin、ProcessorFactory 和 Registry。
- Task 生命周期、分析 FIFO 与执行资源池/按池 LIFO 调度、Runtime 组装入口。

现有 CLI 已迁入独立的 `../fengine` 工程，不属于本 workspace。

当前版本可以分析媒体、生成冻结 Snapshot、创建真实 execution，并对兼容候选链执行 libav packet stream-copy/remux，或执行单视频、无音频的 software decode -> 可选 swscale -> libx264 -> MP4 转码。执行进度、用户暂停/恢复、取消、安全抢占、资源池并发、按池 LIFO 自动恢复与 `OutputTransaction` 已接入 Runtime。音频、多流、HDR tone mapping、任意 Plugin Processor 桥接、未资格化 codec/hardware 以及其他转换组合仍返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`，不会被 native discovery 伪装为 Engine-ready。

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

`framelean-ffmpeg` 不再回退到系统或 Homebrew FFmpeg。开发、测试和发布构建必须先用 `scripts/build/build_ffmpeg_*` 生成被忽略的 bundled static libav SDK，再通过 `scripts/build/with_bundled_ffmpeg.sh` 构建 FLL/FEngine。macOS arm64 已验证最终 FEngine 不依赖任何 `libav*.dylib`；Universal 2 与 Windows x64 由 Desktop Client workflow 分别在原生 runner 上构建并执行同类依赖检查。

Runtime Schema 的 Rust 类型和导出逻辑位于 `crates/framelean-runtime`，生成基线位于 `schemas`，导出 example 与一致性测试继续保留在本 workspace。

## License

FrameLean 主许可证见仓库根 `LICENSE`。
