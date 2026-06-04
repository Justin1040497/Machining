---
name: framelean-implementation
description: "Use to implement confirmed FrameLean tasks after requirements, design, and test boundaries are accepted. Applies to production code, tests, scripts, docs, and project-level skill edits while preserving scope, architecture, user changes, and current project style. Use only inside the FrameLean repository."
---

# FrameLean Implementation

Implement only the confirmed FrameLean scope. This skill starts after the user has accepted the requirement/design/task/test boundary with `可以`.

## Required Context

Read `AGENTS.md`, relevant feature docs, task list, source, tests, and current Git status. Use `docs/develop/architecture.md`, `docs/develop/data-model.md`, `docs/develop/technology-stack.md`, or `docs/develop/git-workflow.md` only when the touched files require those rules.

## Scope Rules

- Do not add unconfirmed features, broad refactors, visual redesigns, generated artifacts, or formatting churn.
- Do not stage, commit, revert, delete, or format unrelated user changes.
- If the confirmed design becomes impossible or risky, stop and explain the conflict before changing scope.
- Prefer existing helpers, providers, use cases, mappers, widgets, and scripts before adding abstractions.
- Add abstractions only when they reduce real duplication, preserve a boundary, or match an established FrameLean pattern.

## Architecture Rules

Follow:

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

- `domain` stays independent of Flutter, Drift, FFmpeg, filesystem, and platform details.
- `application` owns use cases, repository interfaces, service abstractions, and orchestration.
- `infrastructure` implements Drift, FFmpeg, FFprobe, filesystem, process, platform, and service concerns.
- `features/workbench` coordinates UI state through Riverpod notifiers and application use cases.
- `app` remains shell, theme, and routing.

## After Implementation

Report:

- What changed.
- Which confirmed behavior or boundary it satisfies.
- What did not change.
- Any unclear product or business boundary.

Do not move to validation until the user explicitly says `可以`, unless the user asked you to complete implementation and validation in the same turn.
