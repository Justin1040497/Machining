# Analysis Flow

媒体分析与 Runtime 聚合能力属于 FrameLean 核心处理库 FLL。`framelean-runtime` 的 Rust 类型是 Runtime Schema 的代码源头；导出 example、一致性测试与生成基线共同保存在 `fll`。

FEngine 是独立引擎进程和执行宿主边界，当前仅通过 CLI Bootstrap 装配并调用 FLL 的公开 API。常驻服务、跨进程通信、父进程监控和会话管理尚无真实实现，本阶段不创建对应占位模块；FLL 的进程内 Snapshot、Task、Scheduler 和 Runtime 继续由 FLL 拥有。
