# Machining 文档入口

## 文档目的

这个目录用于帮助开发者和 AI 快速理解 Machining 当前状态、代码边界和后续功能开发流程。

阅读文档时优先区分两类内容：

- 当前事实：已经实现、正在使用、会影响代码修改的内容。
- 历史记录：开发过程、阶段日志和旧计划，不一定代表当前实现。

## 当前版本

- 当前版本：v1.0.0
- 当前状态：macOS Apple Silicon 本地视频压缩主链路完成
- 下一阶段：v1.1 发布打磨，v2.0 轻量化界面和交互可以作为后续功能版本规划

## 推荐阅读顺序

AI 处理任务前建议先读：

1. `docs/product/README.md`：产品定位、当前版本范围和不做什么。
2. `docs/architecture/README.md`：架构分层、核心模块和验证命令。
3. `docs/architecture/tech-stack.md`：当前技术栈和项目事实。
4. `docs/features/README.md`：新增功能版本的文档流水线。

如果任务涉及发布、测试或许可，再阅读对应目录下的文档。

## 目录职责

```text
docs/
  product/       产品范围、需求、设计和路线图
  architecture/  项目结构、技术栈、数据模型和代码边界
  features/      功能版本开发流水线和单功能文档
  develop/       发布计划、测试计划和开发验证说明
  reference/     许可证、分发、图表等参考资料
  archive/       历史日志和旧计划
```

## 文档规则

- 当前事实优先放在 `product/`、`architecture/`、`develop/`。
- 新功能优先在 `features/<feature-name>/` 建立流水线文档。
- 历史过程记录放入 `archive/`，不要作为当前实现依据。
- 如果历史文档和当前文档冲突，以当前文档和源码为准。
