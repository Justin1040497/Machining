# FEngine 下一版本发布草稿

- 提供 `analyze`、`environment` 和 `monitor` CLI 验证入口，用于装配并调用 FLL 的公开能力。
- 提供本地长度帧 JSON Worker、stdio 诊断入口、随机 token 认证的 loopback 守护连接、会话与心跳、幂等请求、单槽外部 Work Queue 和 AnalysisSnapshot 目录存储。
- 支持单项/批量分析与执行、双 revision 队列重排、Video/Auxiliary 资源池、多个活动 execution、Engine Snapshot、进度、暂停/恢复/取消和按池 LIFO 抢占恢复。
- 通过 FLL 和进程内 libav 执行可兼容媒体的 packet stream-copy/remux，输出使用同目录事务和原子发布。
- Client 连接中断或进程重启后可接回同一 Worker session，并以包含双队列、多个活动 execution、两个资源池恢复栈及最近终态摘要的 Engine Snapshot 重建投影。

当前真实 Backend 支持兼容媒体的 packet stream-copy/remux，以及严格限定的单视频、无音频 software decode -> 可选 swscale -> libx264 -> MP4；其他 Decoder、Encoder、音频、多流、HDR 或任意 Processor 组合仍 fail closed。FEngine 守护进程本身崩溃后的跨进程媒体断点续作也不在本草稿范围。
