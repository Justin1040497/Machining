# FEngine Development Changes

- 将原 `framelean-cli` 迁为独立的 `fengine` Cargo 工程，保留 `framelean-engine` 二进制名和现有 CLI 源码。
- 直接本地依赖按迁移前 manifest、源码 import 和测试证据重建，不再作为 `fll` workspace member。
- 将 Cargo package 身份校正为 `framelean-engine`，与 FEngine 的独立引擎进程定位及现有二进制名保持一致，不改变 CLI 行为。
