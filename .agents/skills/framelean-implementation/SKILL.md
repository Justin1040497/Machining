---
name: framelean-implementation
description: "Use to implement confirmed FrameLean tasks after requirements, analysis, plan, and validation boundaries are accepted. Applies to production code, tests, scripts, docs, and project-level skill edits while preserving scope, architecture, user changes, and current project style. Use only inside the FrameLean repository."
---

# FrameLean Implementation

Implement only confirmed FrameLean scope. This skill starts after the user has accepted the requirement, analysis, plan, or requested an end-to-end execution.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Prefer docs first, then the active `.workspace/plans/` file if one exists, then related source/tests found with `rg`.

## Scope Rules

- Do not add unconfirmed features, broad refactors, generated artifacts, or formatting churn.
- Do not stage, commit, push, revert, delete, or format unrelated user changes.
- If the confirmed plan becomes impossible or risky, stop and explain the conflict before changing scope.
- Prefer existing helpers, providers, use cases, mappers, widgets, scripts, and docs patterns.
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

## Documentation During Implementation

Update docs only when the change affects current facts:

```text
CONTEXT.md
CHANGELOG.md
docs/work/*
docs/releases/*
docs/decisions/*
docs/lessons.md
docs/develop/*
docs/reference/*
.agents/skills/*
```

Keep `.workspace/` plans as temporary execution artifacts, not committed facts.

## Handoff

Report:

- What changed.
- Which confirmed behavior or boundary it satisfies.
- What did not change.
- Which validation remains.

Do not move to validation unless the user asked to complete implementation and validation in the same turn.
