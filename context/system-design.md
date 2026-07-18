# System Design

本阶段保持现有组件运行方式。Desktop Client 是当前桌面产品客户端，FLL 是核心处理库，FEngine 是未来承接独立引擎进程生命周期、执行宿主和通信边界的组件。当前 FEngine 仍是 CLI Bootstrap；Desktop Client、Backend 与 FEngine 的新通信协议、进程级职责迁移和 FFmpeg 静态链接迁移均不在当前范围内。

仓库归一化只统一源码、构建输入、脚本与文档入口，不改变业务行为、依赖版本或第三方运行方式。
