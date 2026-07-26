# Schema Responsibility

FEngine protocol v1 的 wire model 代码事实位于 `fengine/src/protocol.rs`。当前尚未建立独立 wire Schema 生成器，因此本目录不保存手写 JSON Schema。

FLL Runtime Schema 由 `fll/crates/framelean-runtime` 导出到 `fll/schemas`，不得复制到本目录。
