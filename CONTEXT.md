# FrameLean Monorepo Context

FrameLean 使用单一根 Git 仓库管理桌面产品客户端、Backend、核心处理库 FLL、独立引擎进程 FEngine 和共享工程资源。Desktop Client 是用户直接使用的桌面产品；FLL 拥有进程内媒体分析、决策、execution Task、Video/Auxiliary 资源池调度、输出事务和 Runtime Schema；FEngine 是装配 FLL 的 Worker 和进程级协议边界。当前端到端路径已覆盖任务夹摊平、独立分析/执行队列、批量提交、双 revision 原子重排、资源池并发与按池 LIFO 抢占恢复、请求幂等、sequence、Client 重启后接回同一守护 Worker 与 Snapshot 对账，以及受支持媒体的真实 libav stream-copy/remux 输出。需要解码、编码或 processor 的转码链仍会明确拒绝。组件边界、构建入口与公共协议职责见 `README.md`、`context/` 和各组件 README。

当前公共协议目录记录 Client 与 FEngine protocol v1 的已实现 transport、命令和所有权边界；wire model 的代码事实位于 `fengine/src/protocol.rs`。FLL Runtime payload 和 Runtime Schema 仍由 `fll/crates/framelean-runtime` 的 Rust 类型与导出逻辑拥有，生成基线保存在 `fll/schemas`。

第三方源码与构建输入位于 `dependencies/`；可重建的第三方二进制只允许进入被忽略的 `build/dependencies/`。本地用户资料只允许位于被忽略的根 `.workspace/`。
