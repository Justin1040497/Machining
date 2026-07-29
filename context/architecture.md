# Architecture

FrameLean Monorepo 包含四个主要组件：`desktop-client` 是用户直接使用的桌面产品客户端，`backend` 提供更新服务与管理后台，`fll`（FrameLean Lib）是进程内核心处理库和 Runtime Schema 代码源头，`fengine`（FrameLean Engine）是依赖 FLL 的独立引擎进程、执行宿主和进程级管理边界。

FLL 拥有媒体模型、分析、环境与能力发现、配置决策、Processor、Pipeline、Plugin、进程内 Task、Scheduler、Runtime、输出事务原语和 Runtime Schema。FEngine 负责装配 FLL，并已承接本地 Worker 生命周期、versioned 长度帧请求入口、受认证的本机回环守护连接、外部 Work Queue、会话与心跳、幂等、Snapshot 磁盘存储，以及错误和终态的进程级出口；它不接管 FLL 的核心处理逻辑。

`fengine` 是独立 Cargo 工程，通过本地 path 依赖使用实际需要的 `fll` crates，不是 `fll` workspace member。FEngine 已实现分析/执行批次、队列 revision 和原子重排、Engine Snapshot、进度与执行控制；FLL Runtime 实现真实 execution、输出事务、Video/Auxiliary 资源池、按池安全暂停和 LIFO 抢占恢复，并从冻结 Candidate 构建、验证和路由跨阶段 native execution plan。Desktop Client 的全部标准媒体路径统一经 Engine Gateway，不保留 Dart FFmpeg Runner、FFprobe 分析器或 FFmpeg 命令规划；每条 AAC 音轨的保留选择、码率、采样率和单/双声道也只能从 Snapshot 候选参数域选择。当前真实 Backend 执行 packet stream-copy/remux、单 SDR 视频加多条 PCM/AAC 音轨的 H.264/AAC MP4 转码，以及多条 PCM/AAC 音轨的 AAC M4A 压缩；多视频流、字幕/数据/附件转码、HDR、任意 Plugin Processor 桥接、未资格化 codec/hardware 和其他转换组合仍 fail closed。Backend 内部模块以 `backend/pom.xml` 为唯一事实来源。
