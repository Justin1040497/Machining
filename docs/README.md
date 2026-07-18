# FrameLean 文档入口

根目录 `CONTEXT.md` 提供当前项目概览，`CHANGELOG.md` 提供版本级摘要。本目录只保存仍有阅读价值的工程事实、版本事实、决策、经验和参考资料。

## 文档地图

```text
docs/
  work/
    active.md                 当前正在推进的事项
    decisions.md              仍有效的重要决策索引
  releases/vX.Y.Z/            已发布版本的稳定事实和 release 文档
  decisions/                  重要决策正文
  develop/
    architecture.md           当前架构与关键运行流程
    data-model.md             当前 Drift 数据模型和迁移事实
    technology-stack.md       当前技术栈与平台边界
    test-plan.md              当前测试与验证范围
    workflow.md               开发、Git、验证、PR 和发布流程
  reference/                  第三方运行时与分发依据
  lessons.md                  可复用经验与避坑记录
```

## 阅读顺序

1. 读 `CONTEXT.md` 快速理解项目。
2. 读 `work/active.md` 确认当前是否有在途事项。
3. 按任务读取相关 `develop/`、`releases/` 或 `decisions/`，不要默认全量加载。
4. 修改代码前读取 `develop/workflow.md` 和相关测试边界。
5. 使用项目 Skills 时读取 `.agents/skills/README.md`。

## 维护规则

- 不记录每日日志、空需求池或已经完成的执行计划。
- 小 bug 不单独建文档；可复用经验进入 `lessons.md`。
- 重要且长期有效的选择进入 `decisions/`，并登记到 `work/decisions.md`。
- 当前事项只进入 `work/active.md`，完成后移除并更新相应稳定事实。
- 已发布版本事实进入 `releases/vX.Y.Z/`；`CHANGELOG.md` 只保留版本级摘要。
- 不创建 `docs/archive/`、`docs/features/`、`docs/plans/` 或 `docs/product/roadmap.md`。
