# FLL v0.1.0 — Initial Architecture Setup

发布日期：2026-07-16

- 建立由六个 crate 组成的 FLL 核心处理库 Rust Workspace。
- 建立媒体、Processor、Pipeline、静态 Plugin、Task 和 Runtime 基础抽象。
- 建立 `Plugin -> Factory -> Processor -> Pipeline -> Runtime` 最小执行闭环。
- 增加 Architecture Foundation 文档和配套验证入口；该可执行入口后来拆入独立 FEngine，不属于 FLL 当前职责。

该版本只提供架构骨架，不具备真实媒体处理能力。
