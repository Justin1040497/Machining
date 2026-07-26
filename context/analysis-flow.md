# Analysis Flow

媒体分析与 Runtime 聚合能力属于 FrameLean 核心处理库 FLL。`framelean-runtime` 的 Rust 类型是 Runtime Schema 的代码源头；导出 example、一致性测试与生成基线共同保存在 `fll`。

当前分析流程为：

```text
Client AnalyzeMedia | SubmitAnalysisBatch
→ FEngine analysis queue
→ FLL Runtime 生成媒体事实、能力、候选、推荐、预设与估算
→ FLL 生成 AnalysisSnapshot
→ FEngine 持久化 Snapshot
→ AnalysisCompleted 返回 Client
```

FEngine 已实现常驻 Worker、受随机 token 保护的本机回环守护连接、会话、心跳、幂等、独立分析队列和 Snapshot 磁盘适配；FLL 继续拥有 AnalysisSnapshot 模型、分析与配置算法、Task、Scheduler、Pipeline 和 Runtime。FEngine 持久化成功之前不会把分析报告为完成。批量分析先整体校验再按 Client 摊平顺序建立独立工作；分析在 Client 离线窗口结束时，Engine Snapshot 的有界终态摘要会引导 Client 重新读取持久化 FLL Snapshot。

新 Client 从 Snapshot 保存 opaque selection，不再把配置保存拆成独立 `ResolveConfiguration` 步骤。执行提交时，FLL 以 analysis ID/revision 和 selection 做同一次原子复核。兼容 RPC 仍可查询旧 Client 的配置解析，但不在新 UI 保存路径中调用。
