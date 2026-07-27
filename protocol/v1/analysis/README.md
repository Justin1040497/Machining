# Analysis Protocol

当前 protocol v1 已实现：

- `AnalyzeMedia`
- `SubmitAnalysisBatch`
- `GetAnalysisSnapshot`
- 对应的 batch-accepted、accepted、queued、started、completed、snapshot-ready 和 failed 输出

分析结束点固定为：

```text
FLL 生成 AnalysisSnapshot
→ FEngine 持久化成功
→ FEngine 在 AnalysisCompleted 同时返回 analysis 与同一 revision 的 snapshot
```

Client 直接保存 `AnalysisCompleted.snapshot` 中的 opaque selection，不再为正常分析结果额外请求 `GetAnalysisSnapshot`。后者只保留给重连恢复、终态摘要对账和显式读取。`SubmitExecution` 时由 FLL 以预期 revision 原子复核。

`SubmitAnalysisBatch` 以客户端已摊平的稳定顺序提交独立工作。批次不引入任务夹语义；任务夹始终属于 Client 产品模型。

分析 payload 的字段与 Schema 由 `fll/crates/framelean-runtime` 和 `fll/schemas` 拥有；FEngine 只负责 transport、队列、会话、持久化和 Client identity 映射。
