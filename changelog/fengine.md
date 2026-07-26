# FEngine Development Changes

- 将原 `framelean-cli` 迁为独立的 `fengine` Cargo 工程，保留 `framelean-engine` 二进制名和现有 CLI 源码。
- 直接本地依赖按迁移前 manifest、源码 import 和测试证据重建，不再作为 `fll` workspace member。
- 将 Cargo package 身份校正为 `framelean-engine`，与 FEngine 的独立引擎进程定位及现有二进制名保持一致，不改变 CLI 行为。
- 增加常驻 Worker 分析垂直切片：长度帧 JSON stdio、版本握手、session、幂等重放、事件序号、心跳监督、单槽优先级 Work Queue、Runtime 就绪门控和结构化终态。
- 增加 AnalysisSnapshot 目录持久化、启动恢复、单实例锁、发布后目录同步、文件名/记录 ID 校验、不可覆盖写入和持久化失败回滚；`serve` 现在要求显式 Snapshot 目录。
- 接入 FLL 的 Analyze、Snapshot 查询和配置解析接口，并在 FLL 边界校验 Client 提交的源 size/mtime；等价在途分析可合并，已完成分析由 Client 使用 `analysis_id` 查询持久化 Snapshot。
- 为长期驻留 Worker 增加有界 ingress、Work Queue、stdout writer、幂等与终态缓存，按实际帧到达时间监督心跳，并为排空、输出背压和超大响应建立明确终态与非零失败退出。
- 为 Snapshot 目录增加条目、总字节和单记录硬上限；容量满时拒绝新 Snapshot，不静默淘汰仍可能被 Client 引用的分析结果。
- 拆分分析队列和 execution/control 队列，增加独立 revision、权威位置、`GetEngineSnapshot` 和同时校验两队列的原子 `ApplyQueueOrder`。
- 增加 `SubmitAnalysisBatch` / `SubmitExecutionBatch`，在完整批次校验后一次建立独立子工作；子 request ID 与超长父 ID 解耦并始终满足协议上限。
- 转发 FLL execution 的进度、暂停、恢复、取消、抢占关系和终态，增加 `PreemptAndStart` 与 `ControlExecution`；幂等重放不重复控制或压栈。
- 默认 Runtime Host 接入真实 libav packet stream-copy/remux Backend，并以真实 WAV 文件覆盖“启动 Worker 子进程 → protocol 分析 → 提交 → 真实进度 → 输出发布 → protocol 重新分析”端到端测试。
- 增加受随机 token 保护的本机 loopback 守护 transport；Client 断开后守护层代发心跳，同一 Worker session 可由新 Client Hello 接回。Engine Snapshot 同时保留有界的最近分析与执行终态摘要，覆盖离线窗口内完成、失败或取消后的投影恢复。
