# Architecture Documentation

跨组件当前架构入口见 `context/architecture.md` 和 `context/system-design.md`。组件内部实现事实由各组件 README、manifest、源码与测试负责。

## 已实现流程图

- 单任务完整闭环时序图：[PNG](assets/single-task-lifecycle-sequence.png) · [SVG](assets/single-task-lifecycle-sequence.svg)。从媒体导入、分析排队、Snapshot 驱动配置、执行提交和运行控制，到完成、失败、取消及重连对账。图中的执行对应当前可用的 libav stream-copy/remux 链，不代表完整转码链已实现。
