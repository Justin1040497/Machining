# FrameLean Monorepo Context

FrameLean 使用单一根 Git 仓库管理桌面产品客户端、Backend、核心处理库 FLL、独立引擎进程 FEngine 和共享工程资源。Desktop Client 是用户直接使用的桌面产品；FLL 提供进程内核心处理能力；FEngine 是依赖 FLL 的执行宿主和进程级管理边界，当前实现仍处于独立 CLI Bootstrap 阶段。组件边界、构建入口与公共协议职责见 `README.md`、`context/` 和各组件 README。

当前公共协议目录只定义所有权和版本边界。Runtime Schema 由 `fll/crates/framelean-runtime` 的 Rust 类型与导出逻辑生成，基线保存在 `fll/schemas`。

第三方源码与构建输入位于 `dependencies/`；可重建的第三方二进制只允许进入被忽略的 `build/dependencies/`。本地用户资料只允许位于被忽略的根 `.workspace/`。
