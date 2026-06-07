# 项目 workflow 基础

## 所属版本

`v1.1.0`

## 当前事实

`v1.1.0` 开始把 FrameLean 的需求讨论、分支、测试、实现、验证和 PR 准备流程写成项目级 workflow，并引入项目级 agent skill。

## 设计方式

- `AGENTS.md` 作为共享 agent 入口。
- `.agents/skills/framelean-workflow` 作为项目 workflow 路由入口。
- `main` 作为唯一长期主干，日常改动通过短分支和 PR / MR 合入。
- 提交和 PR 文案使用固定中文段落结构。

## 当前演进

后续文档重构已将原 `project-workflow.md` 和 `git-workflow.md` 合并为 `docs/develop/workflow.md`。`v1.1.5` 又将项目级 skills 从阶段拆分型结构收敛为职责型结构，当前以 `docs/develop/workflow.md` 和 `.agents/skills/README.md` 为准。

## 关联

- `docs/develop/workflow.md`
- `.agents/skills/README.md`
- `.agents/skills/framelean-workflow/SKILL.md`
