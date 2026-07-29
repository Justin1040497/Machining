# Protocol Boundary

`protocol/v1` 是当前跨组件协议版本入口。已实现部分是 Client 与 FEngine 之间的长度帧 JSON 握手、stdio 直连及受随机 token 保护的本机回环守护 transport、单项/批量分析与执行、双队列重排、运行控制、幂等重放、事件 sequence 和引擎 Snapshot 对账，代码源头为 `fengine/src/protocol.rs`。

FLL Runtime payload 仍由 `fll` Rust 类型和 `fll/schemas` 拥有；公共协议文档只引用这些模型，不复制 Runtime Schema，也不建立第二套字段权威。

分析队列和 FLL execution scheduler 使用独立 revision。`ApplyQueueOrder` 对两者做一次原子校验与更新，冲突时返回当前 Snapshot。执行控制面实现 pause/resume/cancel 和安全点 `PreemptAndStart`；Video/Auxiliary 容量规则、多个活动 execution 和两个按池 LIFO 恢复栈归 FLL Runtime 所有，FEngine 只投影 `active_executions`、`video_resume_stack`、`auxiliary_resume_stack` 与各事件的 `resource_pool`。Runtime 从 Snapshot 冻结的 Candidate 构建和验证 native execution plan；Candidate 与 OptionGraph 声明多条 AAC 音轨及码率、采样率和单/双声道可选域，selection 的非空 `audio_streams` 列表冻结保留集合和逐轨选择，省略该字段表示保留 Candidate 全部音轨，FEngine 只负责透传。当前 Backend 支持 libav packet stream-copy/remux、单 SDR 视频加多条 PCM/AAC 音轨的 H.264/AAC MP4 转码，以及多条 PCM/AAC 音轨的 AAC M4A 压缩。多视频流、字幕/数据/附件、HDR、任意 Plugin Processor 桥接、未资格化 codec/hardware 和其他转换组合仍 fail closed。
