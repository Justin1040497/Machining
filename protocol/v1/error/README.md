# Error Protocol

FEngine wire error 包含：

```text
code
engine_code
message
retryable
```

`code` 描述协议或 Worker 边界错误，例如版本不兼容、握手缺失、session 不匹配、request ID 冲突、`WorkerBusy`、Worker draining、心跳超时、`ResponseTooLarge`、Runtime 失败或 Snapshot 存储失败。

`WorkerBusy` 表示有界队列或幂等保留区暂时没有容量，可在退避后使用同一业务意图重试。`ResponseTooLarge` 保留原 request ID 和 sequence，表示终态无法放入 protocol v1 的 16 MiB 单帧；它不会通过断流伪装成成功。

`engine_code` 在错误来自 FLL 时保留 FLL 的稳定错误分类。日志不通过错误帧伪装，始终写入 stderr。

当 `SubmitExecution` 选中音频、多流、HDR、任意 Plugin Processor 桥接、未资格化 codec/hardware 或其他尚未就绪的转换组合时，以 `WorkFailed` 返回 Worker `RuntimeFailure`，并在 `engine_code` 中保留 FLL 的 `ENGINE_EXECUTION_CHAIN_NOT_READY`；这不是成功提交或可重试的进度状态。可兼容的 packet stream-copy/remux，以及严格限定的单视频、无音频 libx264 转码链会创建真实 execution，后续失败以 `ExecutionFailed` 报告。
