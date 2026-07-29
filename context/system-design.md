# System Design

Desktop Client 是桌面交互、本地产品状态和展示边界；FEngine 是本地独立 Worker、外部请求队列、会话、Snapshot 持久化和进程级协议边界；FLL 是媒体分析、能力决策、配置解析、Pipeline、Task、Scheduler、输出事务原语和 Runtime Schema 的进程内核心库。Backend 独立提供更新服务与管理后台，不进入本地媒体处理链。

当前 Client 通过受随机 token 认证的本机 loopback Engine Gateway 使用 FEngine 的分析、Snapshot、批量执行、双队列重排、进度和 pause/resume/cancel/抢占控制。守护 transport 在 Client 断开或进程重启期间维持同一 Worker session，重连后由 Engine Snapshot 恢复队列、多个活动 execution、两个资源池恢复栈及离线终态。Client 任务夹是展示与产品顺序模型；FEngine/FLL 只接收摊平后的独立任务。FLL Runtime 是 execution state、安全暂停点、用户暂停集合、按资源池 LIFO 恢复栈和媒体参数资格的唯一权威源，并从冻结分析结果构建、验证和路由 native execution plan；Client 只显示并提交 Snapshot 声明的逐轨保留选择、AAC 码率、采样率和单/双声道参数。默认 Backend 已接入真实 libav stream-copy/remux、单 SDR 视频加多条 PCM/AAC 音轨的 H.264/AAC MP4 转码，以及多条 PCM/AAC 音轨的 AAC M4A 压缩；多视频流、字幕/数据/附件、HDR、任意 Plugin Processor 桥接、未资格化 codec/hardware 和其他转换组合仍 fail closed。
