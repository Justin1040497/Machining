# FEngine Context

FEngine 是 FrameLean 的独立 Worker、外部请求队列和进程级管理边界。`src/protocol.rs` 是 wire model 的代码事实，`src/worker.rs` 是会话、幂等、事件与请求调度的事实，`src/daemon.rs` 是 Client 重启可恢复的本机认证 transport，`src/work_queue.rs` 拥有外部队列 revision 和重排，`src/runtime_host.rs` 保留 RuntimeHost seam 与静态兼容实现，`src/fll/` 负责 FLL 动态库 ABI loader 和 Phase 2A typed adapter，`src/snapshot_store.rs` 是 AnalysisSnapshot 持久化适配器。

仓库根级 `rust-toolchain.toml` 固定 Rust 1.98.0；FEngine 的本地构建、release 脚本和 CI 共享这一 baseline。该版本用于避开已验证的 macOS release proc-macro Mach-O LINKEDIT 对齐问题；不改变 FEngine/FLL 的 ABI 或 DTO 所有权边界。

当前可用请求为：

- `Hello`
- `AnalyzeMedia`
- `SubmitAnalysisBatch`
- `GetAnalysisSnapshot`
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

`serve` 必须接收 `--snapshot-dir`；`serve-daemon` 还必须接收 `--endpoint-file`。Desktop Client 将 endpoint 文件置于 Snapshot 目录的父级 engine 目录，Snapshot 存储目录只能包含 AnalysisSnapshot 记录。目录存储持有单实例文件锁，并限制条目数、总字节和单记录字节；容量满时明确失败，不会静默删除 Client 仍可能引用的 Snapshot。Snapshot 先由 FLL 生成，再由 FEngine 原子发布并在支持的平台同步父目录。恢复时文件名必须与记录内的 `analysis_id` 一致，重复 ID 或冲突 revision 不会覆盖已恢复 Snapshot。外部持久化失败时，FEngine 会从 Runtime 回滚尚未提交的内存 Snapshot。

FLL 的媒体分析、候选、预设、估算、Task、资源池 execution Scheduler、Pipeline、输出事务和 Runtime Schema 不迁入 FEngine。FEngine 将 FLL execution event 转换为带 Client identity、资源池和全局 sequence 的协议事件，但不成为 Task state 或按池 LIFO 恢复栈的第二权威源，也不解释 Snapshot 中的逐轨保留集合、AAC 参数或图片质量、无损、缩放 selection。FLL Runtime 从冻结的 Candidate 构建并路由 native execution plan；默认 Runtime 已能执行可兼容的 packet stream-copy/remux、严格限定的视频/音频转码，以及 JPEG/PNG/WebP 静态图片转码。其他转换组合仍 fail closed。

FEngine release 构建通过 `scripts/build/with_bundled_ffmpeg.sh` 使用 `build/dependencies/ffmpeg/<platform>/` 中的 static libav SDK；FLL 动态库承载实际的 FLL Runtime 与 native media code，FEngine 同时保留兼容测试所需的 Rust 依赖。macOS 和 Windows Desktop package 会同时携带 `framelean-engine` 与同目录的 `libframelean_fll.dylib` / `framelean_fll.dll`，不携带或启动 ffmpeg/ffprobe CLI；构建会分别检查 FEngine/FLL 不依赖动态 libav，Windows 还检查 GNU runtime DLL。

Phase 2A 的生产 Runtime 路径是 `Worker/CLI -> DynamicRuntimeHost -> libloading -> framelean_fll -> FLL Runtime`。动态库发现只使用 `FRAMELEAN_FLL_LIBRARY` 的显式开发路径或 FEngine 可执行文件同目录的受信任打包位置；缺少动态库、bootstrap、ABI 或 Runtime 创建失败都会 fail-closed。Phase 2B B1 已建立 crate-private `src/runtime_api` transport、projection 和 opaque document 边界，`DynamicRuntimeHost` 在该边界与现有 FLL typed RuntimeHost seam 之间做兼容转换。`protocol.rs`、`worker.rs`、`snapshot_store.rs`、`main.rs` 以及 FEngine 的静态 FLL Cargo 依赖仍未迁移，后续阶段再处理。

`GeneratePreviewFrames` 与 `GenerateVideoThumbnail` 属于 FEngine Control queue。FEngine 只负责协议、源事实校验和 artifact 事件映射，实际解码、缩放、黑帧判断与 BMP 写入由 FLL `framelean-ffmpeg` 完成。
