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
- `framelean-skill-create` 负责项目级 skills 的创建、合并、删除和重构。

共享预读协议放在 `.agents/skills/README.md`。单个 `SKILL.md` 只保留独有职责和增量读取规则。

交付文案采用按风险递增的精简结构：普通 PR 只写 `Summary` 和可选 `Notes`，不写 `Verification`，例行验证由 CI 和合并门禁承载；Release 只提炼用户可感知的主要变化、重要修复、兼容性与已知问题，并链接完整记录，不重复内部测试、打包检查和文件清单。

## 背景

旧结构中，`framelean-feature-design`、`framelean-feature-tasks`、`framelean-test-plan` 和 `framelean-review` 与当前文档架构不匹配。它们容易把一次工作拆成多个临时文档，也容易让 agent 重复读取项目背景和过期计划。

同时，release 文档和 delivery 文案承担不同目的：release 需要围绕用户指定版本号总结和讨论；delivery 需要保证当前项目事实准确，并给出提交和 PR 文案。

## 影响

- 临时设计、任务和验证边界写入 ignored 的 `.workspace/plans/`。
- Release 草稿可以写入 ignored 的 `.workspace/release-drafts/`。
- `docs/` 继续只保存当前事实、版本事实、重要决策和可复用经验。
- `framelean-delivery` 在交付前检查受变更影响的事实文档，避免旧内容继续作为事实存在。
- PR 和 Release 不再使用必须填满的固定章节；内容长度由真实评审风险和用户影响决定，空章节直接省略。

## 关联

- `.agents/skills/README.md`
- `.agents/skills/framelean-workflow/SKILL.md`
- `.agents/skills/README.md`
