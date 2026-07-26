# FEngine 下一版本发布草稿

- 提供 `analyze`、`environment` 和 `monitor` CLI 验证入口，用于装配并调用 FLL 的公开能力。
- 提供本地长度帧 JSON Worker、stdio 诊断入口、随机 token 认证的 loopback 守护连接、会话与心跳、幂等请求、单槽外部 Work Queue 和 AnalysisSnapshot 目录存储。
- 支持单项/批量分析与执行、双 revision 队列重排、Engine Snapshot、进度、暂停/恢复/取消和 LIFO 抢占恢复。
- 通过 FLL 和进程内 libav 执行可兼容媒体的 packet stream-copy/remux，输出使用同目录事务和原子发布。
- Client 连接中断或进程重启后可接回同一 Worker session，并以包含双队列、活动 execution、LIFO 恢复栈及最近终态摘要的 Engine Snapshot 重建投影。

当前真实 Backend 不包含 Decoder、Encoder 或 Processor，因此不宣称完整压缩/转码链已就绪。FEngine 守护进程本身崩溃后的跨进程媒体断点续作也不在本草稿范围。
