# Execution Responsibility

Protocol v1 实现单项/批量执行提交、队列投影和运行控制：

```text
Client SubmitExecution | SubmitExecutionBatch
→ FEngine 校验与身份映射
→ FLL Runtime 单 execution lane
→ ExecutionSubmitted
→ Started / Progress / Paused / Resumed
→ Completed | Failed | Cancelled
```

请求携带 Client task identity、`analysis_id`、预期 revision、FLL selection、输出请求和 priority。FEngine 将 Client task identity 映射到 FLL `RequestContext.correlation_id`，不把它并入 FLL Task identity。

请求中的输出对象包含绝对 `requested_path`，以及 `fail_if_exists` 或 `generate_unique` 冲突策略。Worker 的 `Accepted`、`WorkQueued` 和 `WorkStarted` 只描述这次外部提交工作的状态，不代表媒体执行 Task 已经创建。

`ExecutionSubmitted` 只在 FLL 已创建真实 execution 后成立，不表示处理完成。`ControlExecution` 提供用户暂停、恢复和取消；`PreemptAndStart` 使当前 execution 先在安全检查点暂停，再启动目标，被抢占的 execution 按 LIFO 自动恢复。完成、失败和取消都会展开恢复链；用户暂停项不参与自动恢复。

当前 Backend 使用进程内 libavformat/libavcodec/libavutil 执行可兼容媒体的 packet stream-copy/remux，不调用 `ffmpeg`/`ffprobe` executable。输出先写同目录临时文件，成功后按冲突策略原子发布；失败或取消回滚临时文件。需要解码、编码或 processor 的 selection 仍明确返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`。
