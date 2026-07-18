# 文档信息架构重构

## 状态

有效

## 决策

FrameLean 文档不再使用 `docs/archive/`、`docs/features/`、`docs/plans/` 和 `docs/product/roadmap.md` 作为常规入口。新的文档架构改为：

- `CONTEXT.md`：项目背景、当前上下文、产品定位、架构和平台边界。
- `changelog/desktop-client.md`：根目录版本变化摘要。
- `docs/work/`：当前任务和有效决策索引。
- `docs/releases/desktop-client/vX.Y.Z/`：按发行版本记录事实设计说明。
- `docs/decisions/YYMMDD-summary.md`：重要决策正文。
- `docs/develop/`：当前工程事实和工作流规则。
- `docs/lessons.md`：踩坑记录和经验总结。
- `docs/reference/`：外部参考和分发依据。

## 原因

旧结构里，`docs/features/{module}/v1/{analysis,design,tasks,test}` 和 `docs/archive/logs/YYYY-MM-DD-topic.md` 让过程文档过多，长期阅读价值不足。`docs/product/roadmap.md` 又容易和任务追踪混在一起。

新的结构把文档分成几类稳定入口：

- 当前是什么：`CONTEXT.md` 和 `docs/develop/`
- 当前正在推进什么：`docs/work/active.md`
- 版本形成了什么：`docs/releases/`
- 为什么这样做：`docs/decisions/`
- 以后别再踩什么坑：`docs/lessons.md`

## 收益

- 文档入口少，读者更愿意点进去。
- AI 不容易把历史计划和当前事实混淆。
- 版本事实设计可以被决策记录、经验总结和上下文文档互相引用。
- bug 修复不再强制一事一文，减少无人阅读的碎片文件。

## 影响

- 项目 workflow 和 skills 需要改为引用 `docs/develop/workflow.md`、`changelog/desktop-client.md`、`docs/lessons.md` 和 `docs/releases/`。
- 历史过程文档不再保留为常规资料；可复用内容被抽取到新入口。

## 关联

- `CONTEXT.md`
- `docs/README.md`
- `docs/releases/desktop-client/v1.1.5/repository-structure.md`
