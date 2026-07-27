# FLL Development Changes

- 将 Rust 库 crates、workspace、Runtime Schema 导出实现、生成产物和一致性测试归入 `fll`。
- 增加 Analysis、Environment、Decision 与 FFmpeg Adapter 的库职责，并扩展媒体分析、能力求交、Runtime Snapshot 和配置解析模型。
- 修复音频时长换算、动图证据、Partial Warning、输入 Profile 校验、位深回退、Preset 过滤、Warning 聚合和分析 Fingerprint 原子性。
- 将 Capability 判断收敛为对输入媒体、静态环境、Backend 明确约束、Engine readiness、HDR/10-bit 和 Muxer 组合的 fail-closed 求交。
- 将 AnalysisSnapshot 扩展为可序列化、可恢复且可查询的完整分析事实，包含输入要求、环境与 Backend 摘要、完整候选链、配置选项图、推荐、预设、估算、风险、有效性、冻结 estimator policy 和 decision/estimator model revision；重复 ID 与冲突 revision 不再覆盖已恢复 Snapshot。
- 配置解析只使用 Snapshot 冻结候选，不再因当前环境、Backend Catalog、Resolver、Preset 或 estimator policy 变化而改写同一 analysis revision。
- Analysis ID 改为跨 Runtime/进程不复用的 UUID v4；新增期望源事实校验和外部持久化失败时的 Snapshot 回滚接口。
- 将 execution scheduler 扩展为 Video 1 槽与 Auxiliary 动态 1/2 槽；多个活动任务共享普通等待队列，两个资源池分别维护 LIFO 恢复栈，并保留安全 checkpoint、暂停失败不启动目标、目标启动失败回滚和用户暂停不自动恢复语义。
- 实现 execution worker、真实进度/状态事件、协作式 pause/resume/cancel 和原子 `OutputTransaction` 发布/回滚。
- `framelean-ffmpeg` 增加进程内 libavformat packet stream-copy/remux，以及严格限定的单视频、无音频 software decode -> 可选 swscale -> libx264 -> MP4；不调用外部 FFmpeg executable，音频、多流、HDR、任意 Plugin Processor 桥接和其他未资格化转换组合仍 fail closed。
- Capability Resolver 对未知 stream 和缺失视频必需事实阻断候选生成，同时不再把没有 codec profile 的 PCM 音频错误当成缺失视频 profile。
- `AnalysisId` 复用 Rust 生态的 `uuid` 1.x（只启用 v4 feature），避免自实现随机 ID 与序列化边界；队列/LIFO 状态机因具有 FrameLean 特有原子不变量，保持小型自有实现，未引入通用任务调度框架。
