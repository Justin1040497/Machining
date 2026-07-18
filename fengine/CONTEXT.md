# FEngine Context

FEngine（FrameLean Engine）是 FrameLean 的独立引擎进程、执行宿主和进程级管理边界。它负责装配 FLL；进程生命周期、运行隔离、外部执行请求及状态、进度、日志、错误和结果出口属于其长期职责。

当前 `src/main.rs` 只实现 `framelean-engine` CLI Bootstrap 和内联测试，负责解析命令、装配 Adapter 与 Runtime，并调用 `../fll/crates/` 提供的核心处理能力。常驻服务、IPC、父进程监控、会话管理和完整执行宿主尚未实现，不得将这些目标写成当前能力。

FLL 的媒体处理、Task 状态、Scheduler、Pipeline、Plugin、Runtime 和 Runtime Schema 不迁入 FEngine。
