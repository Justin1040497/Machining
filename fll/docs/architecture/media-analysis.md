# 媒体分析与配置决策架构

`framelean-analysis` 只回答“媒体是什么”并保留 OS-native 本地路径；`framelean-environment` 只报告机器事实；`framelean-media::capability` 保存中立 Backend 事实；`framelean-decision` 从 `InputMediaRequirements` 验证完整链并生成配置决策；`framelean-runtime` 拥有最终聚合 DTO 和 Snapshot。

完整可执行链为：

```text
Demuxer -> Decoder -> necessary Processor -> Encoder -> Muxer
```

Backend 分别报告 Native support、Engine registration 和 Engine execution readiness。只有所有必要 Stage 均 execution-ready 且格式相容时，`configuration_status` 才为 `available`。当前 FFmpeg Adapter 只提供 Native 事实，因此正常分析会返回媒体 complete/partial、配置 unavailable 和 `ENGINE_EXECUTION_CHAIN_NOT_READY`。

`CapabilityConstraint` 明确区分 unknown、unrestricted、restricted 和 unsupported。Unknown 不得自动视为支持。输入 Profile 只由 Decoder 校验；Encoder 必须独立选择并在 Candidate 中记录输出 Profile。输入 Codec/Profile/Pixel Format/Bit Depth/HDR、OS/CPU/GPU/Native Framework、Backend registration/readiness、Processor HDR preserve/Tone Mapping、Encoder 和 Muxer codec combination 共同决定候选链。HDR→SDR 候选必须显式包含 Tone Mapping Processor。

每条 `ExecutionChainCandidate` 自身包含逐 Stream Decoder、Processor、Encoder、Muxer 和完整输出事实。CapabilitySet 的扁平列表由 Candidate 派生；Recommendation 和 `ResolvedConfiguration` 都以 Candidate 为不可拆分原子。

动态 ResourceSample 不参与 Capability 求交，只参与 Recommendation、Warning 和未来调度保护。
