---
name: framelean-feature-tasks
description: "Use for FrameLean project-level task breakdown from an accepted design.md into ordered, file-level tasks with statuses, dependencies, code skeletons, test/doc tasks, and explicit out-of-scope boundaries before implementation. Use only inside the FrameLean repository."
---

# FrameLean Feature Tasks

Convert an accepted FrameLean design into an executable task list. This skill writes or drafts `tasks.md`; it does not implement tasks.

## Required Context

Read the feature `design.md`, related `analysis.md` if present, `AGENTS.md`, `docs/README.md`, `docs/develop/architecture.md`, and source/tests for existing patterns. Use `docs/develop/git-workflow.md` only when task order depends on branch or release constraints.

Preserve the `framelean-workflow` gate: do not write tests or production code until the user explicitly says `可以`.

## Document Location

Keep task files beside their design files:

```text
docs/features/{module}/{version}/tasks.md
docs/features/{module}/{version}/client/tasks.md
docs/features/{module}/{version}/server/tasks.md
```

Use client/server split only when the design already split those responsibilities.

## Output Shape

Use Chinese.

```markdown
# {模块名} — 任务清单

基于 `design.md`，列出本次需要创建或修改的具体文件。

全局约束：
- {架构、状态管理、平台或禁止事项}

---

## 执行顺序

1. ⬜ 任务 1 — {摘要}（无依赖）
2. ⬜ 任务 2 — {摘要}（依赖任务 1）
3. ⬜ 最后 — 测试计划、验证路径和文档同步

---

## 任务 1：{文件名} — {改动摘要} `⬜ 待处理`

**文件：`{完整项目相对路径}`**

**类型：** 新建 / 修改 / 配置 / 文档 / 测试

### 1.1 {具体改动点} `⬜`

{说明与必要骨架}
```

## Task Rules

- One task should map to one primary file when practical.
- Merge tightly coupled files only when separating them would make execution ambiguous.
- Order tasks as: domain definitions, application contracts/use cases, infrastructure implementations, feature/UI wiring, tests, docs.
- Include test tasks, but put detailed test planning in `framelean-test-plan` when a separate test document is needed.
- Include documentation tasks when architecture, data model, test scope, release flow, user-visible behavior, or developer workflow changes.
- Do not include content explicitly listed under "暂不实现" in design.
- Use status marks consistently: `⬜ 待处理`, `🔧 进行中`, `✅ 已完成`.
- Provide skeletons only: signatures, fields, SQL, imports, widget structure, or logic steps. Do not write full implementation bodies.

## FrameLean Boundaries

Respect current project architecture and naming. Prefer existing helpers, providers, use cases, dialog components, FFmpeg planning helpers, Drift mappers, and test patterns before inventing new ones.
