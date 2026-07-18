# FEngine

FEngine（FrameLean Engine）是 FrameLean 的独立引擎进程、执行宿主和进程级管理边界。它负责装配 FLL，并将在真实实现到位后承接引擎进程生命周期、运行隔离、外部执行请求，以及状态、进度、日志、错误和结果的进程级出口；核心媒体处理、Task 状态、Pipeline、Plugin 和 Runtime 继续由 FLL 拥有。

当前 `fengine` 是独立 Cargo 工程，实际实现仅达到 `framelean-engine` CLI Bootstrap：解析命令、装配 Adapter 与 FLL Runtime，并调用 FLL 的公开 API。它只声明 manifest、源码 import、features、测试和 examples 证明为直接使用的依赖。

```bash
cargo run -- --version
cargo run -- demo
cargo run -- environment --json
cargo run -- analyze <path> --mode video-compress --json
cargo run -- monitor --samples 3 --interval-ms 1000 --json
```

当前尚未实现常驻服务、IPC、父进程监控、会话管理或完整执行宿主。本阶段不为这些未来职责新增空模块。
