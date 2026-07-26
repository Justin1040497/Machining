# Protocol Boundary

`protocol/v1` 是当前跨组件协议版本入口。已实现部分是 Client 与 FEngine 之间的长度帧 JSON 握手、stdio 直连及受随机 token 保护的本机回环守护 transport、单项/批量分析与执行、双队列重排、运行控制、幂等重放、事件 sequence 和引擎 Snapshot 对账，代码源头为 `fengine/src/protocol.rs`。

FLL Runtime payload 仍由 `fll` Rust 类型和 `fll/schemas` 拥有；公共协议文档只引用这些模型，不复制 Runtime Schema，也不建立第二套字段权威。

分析队列和 FLL execution lane 使用独立 revision。`ApplyQueueOrder` 对两者做一次原子校验与更新，冲突时返回当前 Snapshot。执行控制面实现 pause/resume/cancel 和安全点 `PreemptAndStart`；抢占恢复栈归 FLL Runtime 所有。当前执行 Backend 只支持不含转换阶段的 libav stream-copy/remux 候选链，完整转码仍 fail closed。
