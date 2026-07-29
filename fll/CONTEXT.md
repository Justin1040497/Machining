# FLL (FrameLean Lib) 项目上下文

## 项目定位

FLL 是 FrameLean 的核心处理库，负责媒体模型与分析、环境与能力发现、配置决策、Processor、Pipeline、Plugin、进程内 Task、Scheduler、Runtime 和 Runtime Schema。它不是普通工具集合，也不只负责单个媒体任务的分析或决策。

FLL 拥有进程内处理逻辑和执行组合，不负责桌面 UI、跨进程通信或操作系统级引擎进程宿主管理。独立 FEngine 是装配 FLL 的进程级启动与管理边界；当前已实现诊断 CLI、常驻 stdio Worker、分析/执行队列、会话与 Snapshot 持久化、执行控制和事件投影。FLL Runtime 提供真实 libav packet stream-copy/remux、单 SDR 视频加多条 PCM/AAC 音轨的 software decode -> 可选 swscale/swresample -> libx264/AAC -> MP4，以及多条 PCM/AAC 音轨 -> AAC -> M4A 执行 Backend；其余完整转码组合仍未就绪。

FLL 不是 FFmpeg CLI wrapper。FFmpeg 通过 `framelean-ffmpeg` 在进程内链接 bundled static libav 子库；构建入口必须显式提供 `build/dependencies/ffmpeg/<platform>/` SDK，不允许回退到系统或 Homebrew FFmpeg，永久禁止从 FLL 调用 ffmpeg/ffprobe executable。

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
                   + framelean-pipeline + framelean-plugin + framelean-ffmpeg
fengine            -> selected public APIs from FLL crates
                   + framelean-analysis + framelean-environment
                   + framelean-ffmpeg
                   + framelean-plugin + framelean-runtime
```

独立的 `../fengine` 是可执行程序的最外层启动与装配入口，既提供诊断 CLI，也通过 `serve` 装配 FLL Runtime 并承载协议、外部队列、会话和 Snapshot 磁盘适配。`framelean-runtime` 是 FLL 内部的运行时执行与组合边界，负责从 Registry 查询 Factory、创建 Processor、注入并执行 Pipeline，以及管理 Task 生命周期和结果。

`framelean-pipeline` 与 `framelean-plugin` 不互相依赖。Processor API 暂时位于 `framelean-media::processor`：Plugin 提供 Processor Factory，Runtime 创建 Processor 并注入 Pipeline，Pipeline 不知道 Plugin 的存在。Runtime 是 Plugin 与 Pipeline 在 FLL 内部发生组合的唯一位置；FEngine 不直接构建或执行 Pipeline，也不绕过 Runtime 操作 Task 状态。

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
- `BackendId` 和 `AnalysisId` 只由 Core 定义；`AnalysisId` 由 Core 生成 UUID v4 值，不能依赖 Runtime 内存计数；`PresetId` 只由 Decision 定义。
- Environment 不包含 FFmpeg 或 Engine Backend 状态。
- Capability 只使用媒体、静态环境、Backend Catalog 和兼容规则；瞬时资源只影响 Recommendation/Warning。
- Native discovered/initializable 不等于 Engine execution ready。
- 未知 Backend 约束按不支持处理；输入 Profile 由 Decoder 验证，输出 Profile 由 Encoder 明确选择并记录；Container、Codec、Pixel Format、Bit Depth、HDR 策略和环境要求必须经过 Demuxer→Decoder→必要 Processor→Encoder→Muxer 完整链验证。
- CapabilitySet 的客户端选项只从完整 `ExecutionChainCandidate` 派生，并通过 `ConfigurationOptionGraph` 保留每个选项对应的 Candidate 集合；Recommendation、Preset 和用户配置不得跨 Candidate 拼接。

## 分析与配置状态

Runtime 聚合媒体分析、环境、Backend Catalog 和 Decision。媒体状态与配置状态相互独立：媒体可以成功分析，但在完整执行链尚未实现时配置仍为 unavailable。四个产品 Preset 为 `clear`（清晰优先）、`balanced`（均衡推荐）、`chat`（微信发送）和 `compact`（体积优先）；可用 Preset 同时绑定完整 Candidate、`ResolvedConfiguration`、预计体积和风险。自定义目标体积是独立配置模式，Estimator 未校准时明确不可用；未校准基线只提供带明确 basis 的低置信度体积估算，不能用于反推目标码率。

用户的 Manual、Preset 或 Custom Target Size 请求必须携带 `candidate_id`，并在对应 AnalysisSnapshot 的 Candidate 集合内解析为不可变 `ResolvedConfiguration`。Preset Policy 对容器、Codec 和 HDR 兼容性做硬过滤。配置解析只读取 Snapshot 冻结的需求、能力候选、选项图、推荐、预设和 Estimator Policy，不重新调用当前环境、Backend Catalog 或 Capability Resolver；Snapshot 同时保存 decision model revision 与 estimator model revision，Runtime 只对兼容版本重新解析，不兼容时明确拒绝而不是使用升级算法生成不同结果。配置解析不修改分析 Snapshot，也不递增 analysis revision；冲突、源文件变化或 revision 不匹配同样保持原 Snapshot 不变。Analyzer 在分析前后比较 canonical/native path、大小、mtime、平台文件 ID 和有界 BLAKE3 内容摘要组成的 `SourceFingerprint`，Runtime 保存生成媒体事实与 SourceId 的同一份 Fingerprint，查询 Snapshot 时返回当前源文件有效性。

Runtime 可将 AnalysisSnapshot 导出为带 Schema 版本的 `AnalysisSnapshotRecord` 并在新 `EngineRuntime` 中校验、恢复；同一 Runtime 不允许重复恢复相同 `analysis_id`，revision 冲突也不会覆盖已有 Snapshot。FLL 不负责记录的磁盘存储、跨进程传输和生命周期管理，这些属于 FEngine。`AnalysisId` 使用 UUID v4，Runtime 重建后不会从 `analysis-1` 重新复用。

## Task 与 execution 生命周期

```text
Queued -> Running -> Completed | Failed | Cancelled
            |  ^
            v  |
      Preempting -> Preempted -> Resuming
            |
            v
          Paused (user)
```

execution scheduler 使用两个资源池：Video 固定 1 个活动位，Auxiliary（图片/音频）在没有视频时有 2 个活动位、视频运行时收缩为 1 个。用户暂停和抢占暂停分开保存；抢占必须先在 Backend 安全检查点获得 checkpoint，再启动目标。被抢占项进入对应资源池的 LIFO 恢复栈，新任务完成、失败或取消都会优先恢复同池栈顶；用户暂停项不自动恢复。视频启动导致辅助池收缩时，必须安全暂停多余辅助任务；暂停失败时不启动目标，目标启动失败时尝试恢复全部原活动项。

## 执行提交边界

Runtime 定义 `ExecutionSubmissionRequest`、`ExecutionSubmissionResult`、`ExecutionTaskState`、输出冲突策略和 `OutputTransaction`。`submit_execution` 先校验绝对输出文件路径，再基于指定 AnalysisSnapshot 和 revision 重新解析 selection，创建 execution 并加入 lane。实际输出先写同目录临时文件，只有 Backend 成功时才原子发布；失败与取消回滚。

Runtime 从冻结的 `BackendCatalog` 和已解析 Candidate 构建并验证跨阶段 `MediaPipelinePlan`，再将 execution request 路由给 `framelean-ffmpeg` 的 Backend。该 Backend 使用 libavformat 复用输入 stream 参数、重写 packet timestamp 并以交错顺序写入输出；也能对严格限定的单 SDR 视频加多条 PCM/AAC 音轨执行 `decode -> 可选 swscale/swresample -> libx264/AAC -> MP4 mux`，或对多条 PCM/AAC 音轨执行 `decode -> 可选 swresample -> AAC -> M4A mux`。AAC Candidate 在 Snapshot 中声明源 `stream_index` 和允许的码率、采样率、单/双声道参数；省略 selection 的 `audio_streams` 表示保留全部，显式非空列表表示保留集合。ResolvedConfiguration 按源索引稳定排序，Backend 为每条音轨初始化独立 decoder、swresample、FIFO 和 encoder。它支持进度、协作式安全暂停和取消。多视频流、字幕/数据/附件转码、HDR tone mapping、任意 Plugin Processor 桥接、未资格化 codec/hardware 和其他转换组合以 `ENGINE_EXECUTION_CHAIN_NOT_READY` 明确拒绝。

媒体辅助 API 也由 `framelean-ffmpeg` 拥有：媒体元数据继续经 `AnalyzeMedia` / `AnalysisSnapshot` 提供；预览帧使用 libavcodec 解码和 libswscale 转 RGB24；视频缩略图按候选时间点跳过黑帧并输出事务性 BMP。上述 API 不调用 executable，也不进入 FLL execution scheduler。

## 当前非目标

- 多视频流、字幕/数据/附件、HDR 和任意 Plugin Processor 的完整转码 Pipeline
- 将 Native capability 冒充 Engine 可执行能力
- 未资格化 codec/hardware 或不在已实现范围内的压缩/转码 Pipeline
- IPC、HTTP、gRPC 或云端 Worker
- DLL、dylib、so 扫描和跨 Rust ABI 动态加载
- 异步运行时和并行 Pipeline
- AnalysisSnapshot 的磁盘存储、跨进程传输和独立 recalculate CLI

## License

FrameLean 主许可证见仓库根 `LICENSE`。
