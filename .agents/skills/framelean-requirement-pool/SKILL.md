---
name: framelean-requirement-pool
description: "Use for FrameLean requirement-pool discussion. Clarifies candidate requirements with the user, checks current context and backlog, and after explicit confirmation adds or updates entries in docs/work/backlog.md. Does not design, plan, or implement features. Use only inside the FrameLean repository."
---

# FrameLean Requirement Pool

Discuss candidate requirements and keep `docs/work/backlog.md` useful.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Focus on `CONTEXT.md`, `docs/work/backlog.md`, `docs/work/active.md`, related release facts, and related decisions.

## Workflow

1. Restate the proposed requirement in FrameLean terms.
2. Check whether it already exists in `docs/work/backlog.md` or active work.
3. Ask only the questions needed to decide priority, status, next step, and source.
4. After the user explicitly confirms, add or update one backlog row.
5. Do not design, break down tasks, or implement. Route accepted follow-up analysis to `framelean-feature-analysis`.

## Backlog Format

Use the existing table in `docs/work/backlog.md`:

```text
ID | 模块 | 优先级 | 状态 | 候选事项 | 下一步 | 来源
```

Status values:

```text
候选
待确认
已排期
暂缓
```

Priority values:

```text
P0
P1
P2
P3
```

Use the next `B-XXX` ID. Keep `下一步` concrete enough for the next analysis or planning session.
