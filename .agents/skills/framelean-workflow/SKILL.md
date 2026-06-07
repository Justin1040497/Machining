---
name: framelean-workflow
description: "Lightweight router for FrameLean project-level skills. Use when the user is unsure which FrameLean skill to use, asks for the full workflow, or requests work spanning requirements, analysis, planning, implementation, validation, delivery, release documents, or project skill maintenance."
---

# FrameLean Workflow Router

Route to the smallest FrameLean project skill that fits the request. Do not load full workflow detail when one focused skill is enough.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Then load only the target skill and the docs or source files needed for the active request.

## Router

| User intent | Skill |
| --- | --- |
| Discuss candidate requirements and add confirmed items to the backlog | `framelean-requirement-pool` |
| Analyze a feature, current module, requirement, interaction chain, logic tree, dependency, or boundary | `framelean-feature-analysis` |
| Produce a design, compare options, break down tasks, and define validation boundaries | `framelean-feature-plan` |
| Implement confirmed code, tests, scripts, docs, or project-level skill changes | `framelean-implementation` |
| Write a validation plan, review diffs, run checks, explain failures, or re-run verification | `framelean-validation` |
| Calibrate current project facts and prepare Markdown commit information plus PR description | `framelean-delivery` |
| Summarize a user-specified version and create its release document | `framelean-release` |
| Create, merge, delete, or refactor FrameLean project-level skills | `framelean-skill-create` |

## Full Workflow

Only run the full chain when the user explicitly asks for end-to-end execution:

```text
framelean-requirement-pool
framelean-feature-analysis
framelean-feature-plan
framelean-implementation
framelean-validation
framelean-delivery
```

`framelean-release` is separate from delivery. Use it when the user asks for a release document for a specified version.

## Gates

- Do not move from discussion to implementation until the user explicitly accepts the requirement, analysis, or plan, unless the user asked for an end-to-end execution.
- Do not stage, commit, push, tag, create a PR, or publish a release unless the user explicitly asks.
- Keep `.workspace/` for temporary plans and drafts; keep `docs/` for confirmed current facts.
