# FEngine

FEngine（FrameLean Engine）是 Desktop Client 与 FLL 之间的独立 Worker 进程，承载分析、执行、队列和重连对账的进程边界：

```text
Client
→ authenticated loopback daemon transport
→ FEngine versioned length-framed protocol
→ analysis queue + execution control queue
→ FLL Runtime
├→ AnalysisSnapshot persistent store
└→ single execution lane + real libav stream-copy/remux
```

FEngine 当前负责：

- 4-byte 大端长度帧 JSON 协议；支持受 UUID token 保护的 `127.0.0.1` 守护连接，也保留 stdio 直连用于测试和诊断。stdio stdout 只输出协议帧，诊断写入 stderr。
- 协议版本协商、单会话、有限窗口的 request idempotency、单调事件序号和 15 秒心跳监督。
- 分析与执行控制的独立队列和 revision；等价的在途分析请求合并，单项失败不阻断后续工作。
- Client task/file ID 与 FLL analysis ID 的进程边界映射。
- 单项/批量分析与执行、Analysis/Engine Snapshot、双 revision 原子重排、pause/resume/cancel、`PreemptAndStart`、`Ping` 和优雅关闭。
- 把 Client task ID 映射到 FLL execution ID，并将真实进度、抢占关系、恢复深度、输出和终态转换为单调序列的 wire events。
- 有界输入、工作、输出、幂等和终态缓存；队列满、输出背压和超大响应都有明确失败。
- AnalysisSnapshot 的单实例有界目录存储、目录同步、文件名/记录 ID 校验、不可覆盖写入、启动恢复和内存提交回滚。
- Client 断开时由守护层复用固定幂等 Ping 维持同一 Worker session；新连接重新 Hello 后读取包含队列、活动 execution、恢复栈和最近终态摘要的 Engine Snapshot。

FEngine 不生成媒体能力、候选方案、预设或估算，也不构造 Pipeline。这些仍由 FLL Runtime 和 FLL Media Pipeline 拥有。

启动 Worker 时必须显式提供 Snapshot 目录：

```bash
cargo run -- serve --snapshot-dir <directory>
```

Desktop Client 使用守护入口，并将仅限当前用户读取的 endpoint 文件写入 Snapshot 目录：

```bash
cargo run -- serve-daemon --snapshot-dir <directory> --endpoint-file <file>
```

开发诊断 CLI 仍可直接调用 FLL：

```bash
cargo run -- --version
cargo run -- demo
cargo run -- environment --json
cargo run -- analyze <path> --mode video-compress --json
cargo run -- monitor --samples 3 --interval-ms 1000 --json
```

当前限制：

- 默认 FLL Backend 只执行不含 Decoder、Encoder 或 Processor 的 packet stream-copy/remux 链。任一转换阶段未就绪时返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`。
- 新 request ID 不复用已完成 Work 的内存终态；Client 应通过持久化的 `analysis_id` 查询 Snapshot，或显式提交一次新分析。相同 request ID 仍在幂等保留窗口内重放。
- Client 连接中断或 Client 进程重启不会结束守护 Worker；重连后复用原 session 并使用 Engine Snapshot 对账。FEngine 守护进程本身崩溃或显式关闭后的跨进程媒体断点续作尚未实现；Client 会将新引擎 Snapshot 中消失的非终态工作标记为可重试的 recovery failure。
