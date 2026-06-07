# 项目级 Skills 工作流

## 所属版本

`v1.1.5`

## 当前事实

FrameLean 项目级 skills 已从阶段拆分型结构收敛为职责型结构。共享预读协议放在 `.agents/skills/README.md`，单个 `SKILL.md` 只保留独有职责和增量读取规则。

## 设计方式

- `framelean-workflow` 只负责轻量路由。
- `framelean-requirement-pool` 负责需求池讨论，确认后更新 `docs/work/backlog.md`。
- `framelean-feature-analysis` 保留功能分析能力；用户没有指定新需求时，优先从未完成需求池推荐事项。
- `framelean-feature-plan` 合并原设计和任务拆解能力，临时计划写入 `.workspace/plans/`。
- `framelean-implementation` 只实现已确认范围。
- `framelean-validation` 合并验证计划、diff 审查和检查执行能力。
- `framelean-delivery` 负责交付前事实校准，并输出 Markdown commit 信息和 PR description。
- `framelean-release` 根据用户指定版本号讨论并产出 `docs/releases/vX.Y.Z/release.md`。
- `framelean-skill-create` 负责项目级 skill 创建、合并、删除和重构，底层遵循系统 `skill-creator`。

## 为什么这样设计

旧结构把设计、任务、测试计划和审查拆成多个阶段 skill，适合重流程项目，但在 FrameLean 当前文档架构下容易制造重复上下文和过期过程文档。新结构把临时计划留在 `.workspace/`，把长期事实留在 `docs/`。

## 设计收益

- Skill 触发更清晰。
- 上下文读取更节制。
- 临时计划和长期事实分离。
- Release 文档和交付文案职责不再混在一起。

## 关联

- `.agents/skills/README.md`
- `.agents/skills/framelean-workflow/SKILL.md`
- `docs/develop/workflow.md`
