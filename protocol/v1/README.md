# Protocol v1

Protocol v1 实现 Client 与 FEngine Worker 的分析、执行、队列和重连对账控制面。

## Transport

- 同一 framing 可运行在 stdio 直连或 Desktop 使用的 `127.0.0.1` daemon socket 上。
- daemon socket 在协议帧前发送 endpoint 文件中的随机 token 和换行；endpoint 文件在 Unix 上为 `0600`。认证只属于 transport，不改变 wire envelope。
- 每帧为 `4-byte big-endian payload length + UTF-8 JSON payload`。
- 单帧最大 16 MiB，空帧无效。
- FEngine stdout 只输出协议帧；诊断和日志只写 stderr。

## Envelope

请求包含：

```text
protocol_version
session_id
request_id
command
```

输出包含：

```text
protocol_version
session_id
sequence
request_id
output = response | event | error
```

Client 必须先发送 `Hello`。FEngine 协商版本并建立单会话，输出 sequence 在会话内单调递增。daemon transport 上的新 Client 连接可用新的 Hello request ID 恢复仍存活的同一 session，响应 `resumed=true`，不会重置 Runtime、sequence 或幂等缓存。相同 session 与 request ID 的相同命令在有界保留窗口内重放原语义；同一 request ID 携带不同命令会被拒绝。超过队列或保留容量时返回 `WorkerBusy`。

握手响应声明 15 秒 heartbeat timeout。连接存在时 Client 持续发送 `Ping`；Client socket 断开后 daemon 使用固定 request ID 的幂等 Ping 维持 Worker。stdio EOF、非法输入和显式 Shutdown 会进入有截止时间的排空；心跳超时或排空超时触发进程级中止。超出 16 MiB 的输出转换为携带原 request ID 的 `ResponseTooLarge`。

## Implemented commands

- `Hello`
- `AnalyzeMedia`
- `GeneratePreviewFrames`
- `GenerateVideoThumbnail`
- `SubmitAnalysisBatch`
- `GetAnalysisSnapshot`
- `SubmitExecution`
- `SubmitExecutionBatch`
- `ApplyQueueOrder`
- `GetEngineSnapshot`
- `PreemptAndStart`
- `ControlExecution`（`pause | resume | cancel`）
- `Ping`
- `Shutdown`

`AnalyzeMedia` 只接受 Client task/file identity、源路径、size/mtime、task mode、priority 和 force flag。FLL 在分析结果提交前校验源事实；源在排队或分析期间变化时不会生成有效 Snapshot。

`GeneratePreviewFrames` 和 `GenerateVideoThumbnail` 接受 Client task identity、源事实、目标缓存路径和尺寸参数。它们进入 Control queue，调用 FLL 进程内 libav helper，既不占用分析队列，也不进入 execution lane 或改变 LIFO 恢复栈。完成事件分别为 `PreviewFramesReady` 和 `VideoThumbnailReady`。

`SubmitExecution` 接受 Client task identity、`analysis_id`、预期 revision、FLL selection、输出请求和 priority。FLL Runtime 复核冻结 Snapshot、selection 和输出路径，创建真实 execution。相同 request ID 在有界窗口内重放原结果，不会重复入队或重复压栈；不同 request ID 不合并执行提交。

`SubmitAnalysisBatch` 和 `SubmitExecutionBatch` 先校验完整批次，再原子建立各子工作的独立身份和顺序。`ApplyQueueOrder` 同时校验分析队列和执行 lane revision；任一冲突都不部分应用，而是返回最新 `EngineStateSnapshot`。拖拽只重排等待项，不改变正在分析、运行或恢复栈中的工作。

执行 lane 为单活动位，`PreemptAndStart` 在安全检查点暂停当前工作后启动目标，并使用 LIFO 恢复栈。用户暂停与抢占暂停分开投影；前者不会被自动恢复。`ExecutionStarted/Progress/Paused/Resumed/StateChanged/Completed/Failed/Cancelled` 都携带会话内单调 sequence。

`GetEngineSnapshot` 返回当前分析活动项与等待队列、执行活动项、普通等待队列、LIFO 恢复栈、用户暂停集合、两类 queue revision，以及有界的最近分析/执行终态摘要。Client 发现 sequence gap 或重新接入 daemon 后保留同一权威 session 并以该 Snapshot 重建投影；成功分析摘要通过 `analysis_id` 重新读取 FLL Snapshot，执行摘要恢复完成输出、失败或取消。

当前默认执行 Backend 只会运行不需要 Decoder、Encoder 或 Processor 的 libav packet stream-copy/remux 链。需要转换阶段的 selection 以 `ENGINE_EXECUTION_CHAIN_NOT_READY` 明确拒绝，不会伪造进度或成功输出。
