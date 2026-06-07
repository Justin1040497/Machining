# 项目级 skills 改为职责拆分

## 日期

2026-06-08

## 状态

有效

## 决策

FrameLean 项目级 skills 不再按设计、任务、测试计划、审查这些阶段拆分，而是按职责拆分：

- `framelean-feature-analysis` 保留功能分析职责。
- `framelean-feature-plan` 合并设计、方案比较、任务拆解和验证边界。
- `framelean-validation` 合并测试计划、diff 审查和检查执行。
- `framelean-delivery` 负责交付前事实校准，并输出 Markdown commit 信息和 PR description。
- `framelean-release` 只负责根据用户指定版本号讨论并产出 release 文档。
- `framelean-requirement-pool` 负责需求池讨论和 `docs/work/backlog.md` 更新。
- `framelean-skill-create` 负责项目级 skills 的创建、合并、删除和重构。

共享预读协议放在 `.agents/skills/README.md`。单个 `SKILL.md` 只保留独有职责和增量读取规则。

## 背景

旧结构中，`framelean-feature-design`、`framelean-feature-tasks`、`framelean-test-plan` 和 `framelean-review` 与当前文档架构不匹配。它们容易把一次工作拆成多个临时文档，也容易让 agent 重复读取项目背景和过期计划。

同时，release 文档和 delivery 文案承担不同目的：release 需要围绕用户指定版本号总结和讨论；delivery 需要保证当前项目事实准确，并给出提交和 PR 文案。

## 影响

- 临时设计、任务和验证边界写入 ignored 的 `.workspace/plans/`。
- Release 草稿可以写入 ignored 的 `.workspace/release-drafts/`。
- `docs/` 继续只保存当前事实、版本事实、重要决策和可复用经验。
- `framelean-delivery` 在交付前扫描重要根文档和 `docs/`，避免旧内容继续作为事实存在。

## 关联

- `.agents/skills/README.md`
- `.agents/skills/framelean-workflow/SKILL.md`
- `docs/releases/v1.1.5/project-skills-workflow.md`
