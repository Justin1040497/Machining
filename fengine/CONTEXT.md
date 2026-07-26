# FEngine Context

FEngine 是 FrameLean 的独立 Worker、外部请求队列和进程级管理边界。`src/protocol.rs` 是 wire model 的代码事实，`src/worker.rs` 是会话、幂等、事件与请求调度的事实，`src/daemon.rs` 是 Client 重启可恢复的本机认证 transport，`src/work_queue.rs` 拥有外部队列 revision 和重排，`src/runtime_host.rs` 装配 FLL 分析与 execution Runtime，`src/snapshot_store.rs` 是 AnalysisSnapshot 持久化适配器。

当前可用请求为：

- `Hello`
- `AnalyzeMedia`
- `SubmitAnalysisBatch`
- `GetAnalysisSnapshot`
- `ResolveConfiguration`（兼容）
- `SubmitExecution`
- `SubmitExecutionBatch`
- `ApplyQueueOrder`
- `GetEngineSnapshot`
- `PreemptAndStart`
- `ControlExecution`
- `Ping`
- `Shutdown`

Worker 使用 4-byte 大端长度帧 JSON；最大帧为 16 MiB。`serve` 提供 stdio 直连；`serve-daemon` 仅监听 `127.0.0.1`，通过 endpoint 文件中的 UUID token 认证并代理同一 framing。daemon 用进程级文件锁保证单 endpoint 只有一个所有者；endpoint 以原子替换发布，在 Unix 上权限为 `0600`。Client 断开后 daemon 使用固定 request ID 的幂等 Ping 维持 Worker，会话不重置；新连接用新的 Hello request ID 恢复原 session。stdio stdout 只允许协议帧，stderr 是诊断出口。stdout writer 与 Coordinator 分离并使用有界通道，超大终态转换为可关联的 `ResponseTooLarge`。握手响应携带单调 sequence 和 15 秒 heartbeat timeout。

分析工作、执行提交与控制具有独立 queue kind。分析等待队列和 FLL execution lane 分别拥有 revision；`ApplyQueueOrder` 校验两个预期 revision 与完整等待集合，成功时一次应用，冲突时返回当前 Engine Snapshot。活动分析、活动 execution 和恢复栈不被拖拽重排。

相同 session/request ID 在有界窗口内重放原语义，payload 不同则拒绝。批量命令的子 request ID 由 FEngine 生成并受协议长度上限约束。不同 request ID 的 execution 不合并，同 request ID 的抢占重放不会重复压栈。FLL Runtime 未完成 Snapshot 恢复前，工作只能入队，不能开始。

输入通道、Work Queue、输出通道、幂等记录和完整终态缓存都有硬上限；终态缓存同时按数量、总字节和 TTL 淘汰。Engine Snapshot 另带最近 128 条分析和执行终态摘要，使 Client 能恢复离线窗口内完成的分析 Snapshot、完成输出、失败或取消。stdio EOF、非法输入和显式 Shutdown 进入有限时排空，到期会中止 Runtime 进程边界，避免无限挂起；daemon 的 Client socket EOF 只表示断开，不传递为 Worker stdin EOF。

`serve` 必须接收 `--snapshot-dir`；`serve-daemon` 还必须接收 `--endpoint-file`。目录存储持有单实例文件锁，并限制条目数、总字节和单记录字节；容量满时明确失败，不会静默删除 Client 仍可能引用的 Snapshot。Snapshot 先由 FLL 生成，再由 FEngine 原子发布并在支持的平台同步父目录。恢复时文件名必须与记录内的 `analysis_id` 一致，重复 ID 或冲突 revision 不会覆盖已恢复 Snapshot。外部持久化失败时，FEngine 会从 Runtime 回滚尚未提交的内存 Snapshot。

FLL 的媒体分析、候选、预设、估算、Task、execution Scheduler、Pipeline、输出事务和 Runtime Schema 不迁入 FEngine。FEngine 将 FLL execution event 转换为带 Client identity 和全局 sequence 的协议事件，但不成为 Task state 或 LIFO 恢复栈的第二权威源。默认 Runtime 已能通过进程内 libav 执行可兼容的 packet stream-copy/remux；需要转换节点的链仍 fail closed。
