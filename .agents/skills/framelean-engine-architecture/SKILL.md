---
name: framelean-engine-architecture
description: "Reference FrameLean FLL core-library and FEngine process-host responsibilities, current Cargo dependency DAG, and Bootstrap versus Runtime assembly boundaries. Use when adding or moving public types, changing Cargo dependencies or crates, modifying Runtime or FEngine composition, designing protocols, reviewing architecture, or deciding whether behavior belongs in FLL or FEngine."
---

# FLL / FEngine Architecture

把本 Skill 作为领域参考，由分析、计划、实现或验证 Skill 按需加载；不要用它替代阶段流程。先读取 FLL/FEngine 的 README、CONTEXT 和 Cargo manifest，再按目标读取 crate 或 `fengine/src/`。当前依赖事实以 manifest、Cargo metadata 与实际代码引用为准。

## 当前 Cargo DAG

```text
framelean-media    -> framelean-core
framelean-analysis -> framelean-core + framelean-media
framelean-environment -> framelean-core
framelean-decision -> framelean-core + framelean-media
                   + framelean-analysis + framelean-environment
framelean-ffmpeg   -> framelean-core + framelean-media + framelean-analysis
framelean-pipeline -> framelean-core + framelean-media
framelean-plugin   -> framelean-core + framelean-media
framelean-runtime  -> framelean-core + framelean-media
                   + framelean-analysis + framelean-environment
                   + framelean-decision
                   + framelean-pipeline + framelean-plugin
framelean-engine   -> selected public APIs from FLL crates
                   + framelean-analysis + framelean-environment
                   + framelean-ffmpeg
                   + framelean-plugin + framelean-runtime
```

FLL 是 FrameLean 的核心处理库；FEngine 是依赖 FLL 的独立引擎进程、执行宿主和进程级管理边界。当前 FEngine 同时提供诊断 CLI、常驻 Worker 和受 token 保护的本机 loopback 守护连接：Bootstrap 装配 FFmpeg、系统环境服务与 `EngineRuntime`，Worker 在外层实现双队列、会话幂等、Snapshot 持久化和协议出口。不要把 `framelean-runtime` 写成 FEngine 的唯一直接依赖；是否通过 Facade、类型重导出或支持模块收敛依赖属于独立架构决策。

## Crate 职责

- `framelean-core`：ID、`EngineError`、`ErrorKind`、基础单位和 `Observed<T>`；不包含媒体、Pipeline、Plugin 或 Runtime。
- `framelean-media`：媒体与 Processor 模型、中立 Backend capability 契约；不绑定 FFmpeg ABI，不依赖上层。
- `framelean-analysis`：媒体分析领域模型、`MediaSource`、`MediaAnalyzer`；不拥有具体 native Adapter。
- `framelean-environment`：静态机器环境、动态资源采样及 Provider 契约；不包含 FFmpeg 或 Engine Backend 状态。
- `framelean-decision`：完整执行链能力求交、Preset、Recommendation 和 Estimator；不探测 native 系统。
- `framelean-ffmpeg`：进程内 libav Adapter，实现媒体分析、Native Backend Catalog 和兼容媒体的 packet stream-copy/remux；不调用 ffmpeg/ffprobe executable。
- `framelean-pipeline`：`NodeKind`、Builder 和执行；只认识 Processor，不知道 Registry、Plugin 或 Factory 来源。
- `framelean-plugin`：Plugin、Factory、Registry 和 Plugin Processor capability 汇集；当前仅静态注册，不控制 Pipeline，不加载动态库。
- `framelean-runtime`：FLL 内部执行与组合边界；聚合分析、环境、Backend、决策和 Schema，保存 AnalysisSnapshot，拥有 execution Task、Video/Auxiliary 资源池 Scheduler、按池 LIFO 恢复、安全暂停上下文和输出事务，并组装 Plugin / Pipeline。
- `fengine`：独立引擎进程、执行宿主和进程级管理边界；解析参数、装配 Adapter 与 Runtime，并实现长度帧 JSON Worker、本机守护连接、独立分析/执行队列、会话幂等、Client ID 映射和 Snapshot 持久化，不承载核心处理逻辑。

## 两层组装边界

- FEngine Bootstrap 是可执行程序的最外层启动与装配入口，可以依赖所装配服务及 Runtime 的公开 API；`serve` 启动 stdio Worker，`serve-daemon` 启动可供 Client 重连的本机守护 transport。
- Runtime 是 Plugin 与 Pipeline 在 FLL 内部发生组合的唯一位置。
- FEngine 不直接构建或执行 Pipeline，不绕过 Runtime 操作 Task 状态，不实现 Registry、Factory 或 Processor 的核心逻辑。
- Runtime 拥有分析聚合 DTO、JSON Schema、AnalysisSnapshot 和 execution state；Analysis Snapshot 可由 FEngine 目录存储跨 Worker 启动恢复，媒体 execution 上下文仍是进程内状态。

## 进程边界

- FLL 拥有进程内媒体处理、Task 状态、Scheduler、Pipeline、Plugin、Runtime 和 Runtime Schema。
- FEngine 长期拥有引擎进程生命周期、运行隔离、外部请求入口及状态、进度、日志、错误和结果的进程级出口。
- 当前已实现 protocol v1 长度帧 JSON、stdio 与本机 loopback transport、心跳、请求幂等、独立分析/执行队列、Snapshot 存储、批量提交、队列重排、多个活动 execution、进度、暂停/恢复/取消和按资源池 LIFO 抢占恢复。
- FLL 当前真实执行 Backend 支持 libav packet stream-copy/remux、严格限定的单 SDR 视频加多条 PCM/AAC 音轨 software decode -> 可选 swscale/swresample -> libx264/AAC -> MP4，以及多条 PCM/AAC 音轨 -> 可选 swresample -> AAC -> M4A；多视频流、字幕/数据/附件、HDR、任意 Plugin Processor 桥接、未资格化 codec/hardware 和其他转换组合必须返回可识别失败。
- Desktop Client 已接入 Engine Gateway 的完整任务生命周期，并在重连后使用 Engine Snapshot 对账；Client 不保留 Dart FFmpeg Runner、FFprobe 分析器或 FFmpeg 命令规划。
- Client 进程重启可接回仍存活的守护 Worker；守护进程自身崩溃后的跨进程媒体 checkpoint 续作尚未实现。

## 硬规则

- Pipeline 不依赖 Plugin；Plugin 不依赖 Pipeline。
- Core 不向上依赖，Media 不反向依赖上层。
- Native discovered / initializable 不等于任意执行链都已就绪；只有 Backend 可以实际执行的候选才能报告可用，完整转码链缺失时必须 fail closed。
- FFmpeg 只通过 `framelean-ffmpeg` 进程内链接 libav 子库；禁止 executable 或 shell 调用。
- 不因未来可能需要而新增 crate；新 crate 必须有稳定职责和真实需求。
- 源错误的 `From` 转换放在拥有源错误类型的 crate，遵守 orphan rule。
- FrameLean 主许可证以仓库根 `LICENSE` 为准；第三方和上游组件许可证由 `legal/` 与组件许可证说明负责。
