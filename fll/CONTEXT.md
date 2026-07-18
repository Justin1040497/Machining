# FLL (FrameLean Lib) 项目上下文

## 项目定位

FLL 是 FrameLean 的核心处理库，负责媒体模型与分析、环境与能力发现、配置决策、Processor、Pipeline、Plugin、进程内 Task、Scheduler、Runtime 和 Runtime Schema。它不是普通工具集合，也不只负责单个媒体任务的分析或决策。

FLL 拥有进程内处理逻辑和执行组合，不负责桌面 UI、跨进程通信或操作系统级引擎进程宿主管理。独立 FEngine 是装配 FLL 的进程级启动与管理边界；当前仍只有 CLI Bootstrap，尚未实现常驻服务或完整执行宿主。

FLL 不是 FFmpeg CLI wrapper。FFmpeg 通过 `framelean-ffmpeg` 在进程内链接 libav 子库；永久禁止从 FLL 调用 ffmpeg/ffprobe executable。

## 当前架构

依赖箭头表示左侧 crate 依赖右侧 crate：

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
fengine CLI        -> selected public APIs from FLL crates
                   + framelean-analysis + framelean-environment
                   + framelean-ffmpeg
                   + framelean-plugin + framelean-runtime
```

独立的 `../fengine` 是可执行程序的最外层启动与装配入口，负责解析参数、创建 Demo 输入、注册示例 Plugin 并调用 `EngineRuntime`。`framelean-runtime` 是 FLL 内部的运行时执行与组合边界，负责从 Registry 查询 Factory、创建 Processor、注入并执行 Pipeline，以及管理 Task 生命周期和结果。

`framelean-pipeline` 与 `framelean-plugin` 不互相依赖。Processor API 暂时位于 `framelean-media::processor`：Plugin 提供 Processor Factory，Runtime 创建 Processor 并注入 Pipeline，Pipeline 不知道 Plugin 的存在。Runtime 是 Plugin 与 Pipeline 在 FLL 内部发生组合的唯一位置；FEngine CLI 不直接构建或执行 Pipeline，也不绕过 Runtime 操作 Task 状态。

```text
Plugin
  -> ProcessorFactory
  -> Processor
  -> Pipeline
  -> Runtime
  -> Task Completed / Failed
```

## 架构原则

- 所有 Cargo 依赖保持单向，禁止循环依赖。
- Runtime 是 Pipeline 与 Plugin 的唯一组装入口。
- 媒体缓冲区和 Pipeline 数据通过所有权移动，不实现 `Clone` 或 `Copy`。
- Processor 只属于 Packet、Video 或 Audio 中的一个 ProcessingStage。
- v0.1 Pipeline 只允许同 Stage Processor 串联，不自动插入媒体转换节点。
- PluginRegistry 使用 Factory 自身 metadata ID 注册，并拒绝重复 ID。
- Registry 中 ID 唯一，但 PipelineSpec 可以重复使用同一 ID 创建多个 Processor 实例。
- 错误在定义源错误的 crate 转换为 EngineError，遵守 Rust orphan rule。
- `BackendId` 和 `AnalysisId` 只由 Core 定义；`PresetId` 只由 Decision 定义。
- Environment 不包含 FFmpeg 或 Engine Backend 状态。
- Capability 只使用媒体、静态环境、Backend Catalog 和兼容规则；瞬时资源只影响 Recommendation/Warning。
- Native discovered/initializable 不等于 Engine execution ready。
- 未知 Backend 约束按不支持处理；输入 Profile 由 Decoder 验证，输出 Profile 由 Encoder 明确选择并记录；Container、Codec、Pixel Format、Bit Depth、HDR 策略和环境要求必须经过 Demuxer→Decoder→必要 Processor→Encoder→Muxer 完整链验证。
- CapabilitySet 的客户端扁平选项只从完整 `ExecutionChainCandidate` 派生；Recommendation、Preset 和用户配置不得跨 Candidate 拼接。

## 分析与配置状态

Runtime 聚合媒体分析、环境、Backend Catalog 和 Decision。媒体状态与配置状态相互独立：媒体可以成功分析，但在完整执行链尚未实现时配置仍为 unavailable。四个产品 Preset 为 `clear`（清晰优先）、`balanced`（均衡推荐）、`chat`（微信发送）和 `compact`（体积优先）；自定义目标体积是独立配置模式，Estimator 未校准时明确不可用。

用户的 Manual、Preset 或 Custom Target Size 选择必须解析到一条完整 Candidate 后才能生成 `ResolvedConfiguration`。Preset Policy 对容器、Codec 和 HDR 兼容性做硬过滤。成功时 Snapshot 保存结果并递增 revision；冲突、源文件变化或 revision 不匹配时保持原 Snapshot 不变。Analyzer 在分析前后比较 canonical/native path、大小、mtime、平台文件 ID 和有界 BLAKE3 内容摘要组成的 `SourceFingerprint`，Runtime 保存生成媒体事实与 SourceId 的同一份 Fingerprint。

AnalysisSnapshot 仅存在于单个 `EngineRuntime` 进程内。CLI `analyze` 退出后 Snapshot 消失；需要验证重新计算时，通过同一条 `analyze --selection` 命令或 Runtime 集成测试在同一进程完成。

## Task 生命周期

```text
Created -> Queued -> Running -> Completed
                          \-> Failed
```

Task 完成时保存最终 `ProcessOutput`；失败时保存统一 `EngineError`。v0.1 不提供暂停或取消。

## 当前非目标

- 完整 Demuxer、Decoder、Encoder、Muxer 和转码 Pipeline
- 将 Native capability 冒充 Engine 可执行能力
- 真实视频、音频、AI 或解密处理 Pipeline
- IPC、HTTP、gRPC 或云端 Worker
- DLL、dylib、so 扫描和跨 Rust ABI 动态加载
- 异步运行时和并行 Pipeline
- 跨进程 AnalysisSnapshot 和独立 recalculate CLI

## License

FrameLean 主许可证见仓库根 `LICENSE`。
