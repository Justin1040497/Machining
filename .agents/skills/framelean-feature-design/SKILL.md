---
name: framelean-feature-design
description: "Use for FrameLean project-level feature design reports, solution comparison, scope boundaries, module responsibility design, acceptance criteria, and branch-name suggestions after feature analysis or requirement discussion and before task breakdown or implementation. Use only inside the FrameLean repository."
---

# FrameLean Feature Design

Write a FrameLean-specific `design.md` for a feature version. This skill turns an accepted feature direction into a durable design report; it does not implement code.

## Required Context

Read `AGENTS.md`, `docs/README.md`, `docs/develop/architecture.md`, `docs/develop/git-workflow.md`, and any relevant product, data-model, technology, test, script, or source files. If an `analysis.md` exists for the same feature, use it as input.

Preserve the `framelean-workflow` gate: design may propose branch names, but do not create or switch branches until the user explicitly says `可以`.

## Document Location

Use the feature archive area only for project-specific feature design:

```text
docs/features/{module}/{version}/design.md
```

If a feature has clearly separate client and service designs, use:

```text
docs/features/{module}/{version}/client/design.md
docs/features/{module}/{version}/server/design.md
```

Do not create server design files unless a real service/API/backend surface exists in the current checkout or is explicitly approved as part of the feature.

## Output Shape

Use Chinese and keep sections that apply. Do not fill empty sections with boilerplate.

```markdown
---
module: {模块名}
version: {版本号}
date: YYYY-MM-DD
tags: [{标签}]
---

# {模块名} — 设计报告

> 关联分析：[{功能分析}](analysis.md)

## 1. 目标

## 2. 现状分析

## 3. 数据模型与接口

## 4. 核心流程

## 5. 项目结构与技术决策

## 6. 分支建议

| 分支名 | 适用理由 | 风险 |
| --- | --- | --- |
| `feature/...` | ... | ... |

## 7. 验收标准

| 验收条件 | 验收方式 |
| --- | --- |

## 8. 暂不实现

| 功能 | 理由 | 是否预留扩展 |
| --- | --- | --- |
```

## FrameLean Design Rules

- Design from current FrameLean architecture: `features -> application -> domain`, with `infrastructure` implementing application abstractions and depending on domain.
- Keep `domain` independent from Flutter, Drift, FFmpeg, filesystem, and platform concerns.
- Keep `features/workbench` as UI and state coordination through Riverpod notifiers and application use cases.
- Describe FFmpeg / FFprobe, Drift, platform packaging, and scripts only when the feature touches those surfaces.
- State branch-name options with the correct prefix: `feature/*`, `fix/*`, `chore/*`, `docs/*`, `release/*`, or `hotfix/*`.
- Include 2-4 branch candidates unless the user asks for a single exact name.
- Put "暂不实现" boundaries in the report to prevent implementation drift.

## Decision Quality

Do not simply agree with the request. Compare meaningful options by product impact, maintainability, testability, platform risk, and migration cost. If docs and code disagree, state the conflict and whether the code appears ahead of stale docs or appears to violate a current rule.
