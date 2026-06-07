---
name: framelean-feature-plan
description: "Use for FrameLean feature planning after analysis or requirement discussion. Produces design notes, option comparisons, scope boundaries, implementation tasks, validation boundaries, and branch suggestions. Persist plans to .workspace/plans when useful instead of docs, and use only inside the FrameLean repository."
---

# FrameLean Feature Plan

Turn an accepted requirement or analysis into a practical implementation plan. This skill replaces the old separate design and task skills.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Then read the accepted analysis, relevant docs, and only the source/tests needed to understand current patterns.

## Location

Default to inline output for small plans. When a plan should be kept while work is in progress, write it to:

```text
.workspace/plans/YYMMDD-feature-slug.md
```

Do not write temporary design, task, or test-plan files into `docs/`. Stable facts, decisions, and lessons are handled later by `framelean-delivery`.

## Output Shape

Use Chinese.

```markdown
# 功能名 — 实施计划

## 1. 结论

## 2. 现状证据

| 事实 | 证据 |
| --- | --- |

## 3. 方案比较

| 方案 | 好处 | 代价 | 结论 |
| --- | --- | --- | --- |

## 4. 设计说明

## 5. 执行任务

| 顺序 | 任务 | 主要文件 | 依赖 | 状态 |
| --- | --- | --- | --- | --- |

## 6. 验证计划

| 验证项 | 命令或方式 | 覆盖行为 |
| --- | --- | --- |

## 7. 分支建议

| 分支名 | 适用理由 |
| --- | --- |

## 8. 暂不实现

## 9. 可能需要更新的 docs
```

## Planning Rules

- Compare meaningful options by product impact, maintainability, testability, platform risk, and migration cost.
- Respect FrameLean architecture: `features -> application -> domain`, with `infrastructure` implementing application abstractions.
- Keep `domain` independent from Flutter, Drift, FFmpeg, filesystem, and platform concerns.
- Order tasks as domain, application, infrastructure, feature/UI, tests, docs when that order applies.
- Include validation boundaries, but leave command execution to `framelean-validation`.
- Include 2-4 branch suggestions using `feature/*`, `fix/*`, `chore/*`, `docs/*`, `release/*`, or `hotfix/*`.
- Do not implement code in this skill.
