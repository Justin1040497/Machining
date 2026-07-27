# Desktop Client Development Changes

- 将 Flutter 客户端迁入 Monorepo 的 `desktop-client/`，并将仓库级脚本、工具、安装器、法律资料和 CI 入口提升到根目录。
- 将原正式版本记录按版本归档到 `docs/releases/desktop-client/`，不再在组件内混合维护开发流水与发布摘要。
- 将新媒体任务生命周期收敛为 `await_analysis → analysis_queued → analyzing → ready → execution_queued → running → terminal`，Drift schema 升级到 34 并补齐旧状态、队列 revision 和稳定 request ID 迁移。
- 导入批次现在先原子组织任务/任务夹，再以稳定摊平顺序提交 FEngine 批量分析；任务夹仍仅属于 Client。
- 新执行入口统一使用 FEngine，支持原子批量提交、双 revision 队列重排、单任务抢占开始、暂停/恢复/取消、任务夹和全部范围控制。
- 工作台展示 FEngine 权威的分析/执行队列位置、恢复栈深度和抢占关系；sequence gap 保留连接并触发 Snapshot 对账，新引擎会话中消失的非终态工作转为可重试 recovery failure。
- 新配置保存路径直接持久化 Snapshot selection，不再调用独立 `ResolveConfiguration`；旧用例仅保留兼容。
- 继续使用现有 Riverpod、Drift/SQLite 和 uuid，未为任务调度引入新第三方库。由于当前 Flutter SDK 锁定的 analyzer 与新 drift_dev 不兼容，临时将 `sqlparser` 严格锁定为 `0.44.5`；该 override 只解决 `DartPlaceholder.when` 的已知构建不兼容，不扩大运行时依赖面。
- 本地 FEngine Gateway 改为连接随机 token 认证的 loopback 守护进程；普通连接关闭不再发送 Worker Shutdown，显式退出仍会取消非终态执行并关闭引擎。重连对账可从终态摘要恢复离线期间完成的分析 Snapshot 与执行终态。
- 清理 Client 侧启动状态恢复、partial 文件扫描、本地资源调度、并发上限、旧压缩确认启发式和 Windows PID 媒体控制；任务状态、输出事务、风险投影与 execution lane 分别统一归 FEngine/FLL 权威边界，并删除失效的 Dart FFmpeg CLI。
