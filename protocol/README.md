# FrameLean Public Protocol

本目录记录 FrameLean 跨组件协议的版本、所有权和兼容边界。

当前已实现的公共协议是 Desktop Client 与 FEngine 之间的 protocol v1，使用同一长度帧 JSON wire model 覆盖 stdio 直连和随机 token 认证的本机 loopback daemon transport，并提供握手、单项/批量分析与执行、双队列原子重排、运行控制、事件 sequence、同 session 重连和 Engine Snapshot 对账。wire model 的代码事实位于 `fengine/src/protocol.rs`；FLL 分析、配置和执行 payload 的 Rust 模型与 Runtime Schema 仍由 `fll` 单独拥有，本目录不复制其生成 Schema。

执行协议已覆盖提交、进度、安全暂停、恢复、取消、LIFO 抢占恢复和终态。当前默认 Backend 只对可兼容的 packet stream-copy/remux 链执行真实媒体处理；需要解码、编码或 processor 的选择仍明确失败。
