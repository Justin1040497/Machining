# 功能版本开发流水线

## 文档目的

这个目录用于管理后续功能版本。每个功能版本都应有自己的文档目录，让需求、设计、任务和验证结果跟随代码一起演进。

这套流程的目标是：

1. 让人和 AI 都能快速知道一个功能现在处于哪个阶段。
2. 避免需求、设计、任务拆解和测试记录散落在长文档里。
3. 让后续 AI 接手时，不需要重新扫描整个仓库才能理解上下文。

## 推荐目录结构

新增功能时，在 `docs/features/` 下创建一个稳定目录：

```text
docs/features/<feature-name>/
  analysis.md
  design.md
  tasks.md
  test.md
  release.md
```

## 五份核心文档

| 文档 | 作用 | 什么时候写 |
| --- | --- | --- |
| `analysis.md` | 需求分析、用户目标、边界和不做什么 | 动手前 |
| `design.md` | 产品交互、技术方案、数据变化和风险 | 实现前 |
| `tasks.md` | 可执行任务拆解和完成状态 | 实现中 |
| `test.md` | 自动化测试、手动验证和样本结果 | 实现后 |
| `release.md` | 版本结论、迁移说明、遗留问题和归档 | 收尾时 |

## 适配 Machining 的流程

Machining 是 Flutter 桌面应用，不需要强行拆成后端和前端。功能版本可以按下面的顺序推进：

1. 需求分析：确认用户场景、轻量化目标、当前版本边界。
2. 产品设计：确认页面、弹窗、状态流和默认策略。
3. 技术设计：确认 domain、application、infrastructure、features 的改动。
4. 任务拆解：把实现拆成可测试的小任务。
5. 交叉审查：检查产品设计、技术方案和任务是否互相对齐。
6. 实现：按任务逐步修改代码。
7. 测试：补自动化测试和必要的手动验证。
8. 收尾：更新路线图、版本说明和遗留问题。

## 命名建议

功能目录使用短横线命名：

```text
docs/features/lightweight-v2/
docs/features/target-size-compression/
docs/features/release-packaging/
```

## 当前建议功能

如果继续推进新版轻量化界面，可以从下面目录开始：

```text
docs/features/lightweight-v2/
```

它应该先沉淀：

- `analysis.md`：为什么从工作区改成轻量压缩器。
- `design.md`：主界面、任务详情设置、应用设置和运行状态。
- `tasks.md`：Flutter UI、状态模型、设置模型和队列交互改动。
- `test.md`：主流程、暂停恢复、失败重试、空状态和批量任务验证。
- `release.md`：v2.0 范围、和 v1.0 的差异、暂不做的功能。
