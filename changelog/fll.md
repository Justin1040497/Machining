# FLL Development Changes

- 将 Rust 库 crates、workspace、Runtime Schema 导出实现、生成产物和一致性测试归入 `fll`。
- 增加 Analysis、Environment、Decision 与 FFmpeg Adapter 的库职责，并扩展媒体分析、能力求交、Runtime Snapshot 和配置解析模型。
- 修复音频时长换算、动图证据、Partial Warning、输入 Profile 校验、位深回退、Preset 过滤、Warning 聚合和分析 Fingerprint 原子性。
- 将 Capability 判断收敛为对输入媒体、静态环境、Backend 明确约束、Engine readiness、HDR/10-bit 和 Muxer 组合的 fail-closed 求交。
