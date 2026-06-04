---
name: framelean-workflow
description: "Lightweight router for FrameLean project-level skills. Use when the user asks to run the full FrameLean workflow, is unsure which FrameLean skill to use, or requests project work that spans requirement analysis, design, tasks, test planning, implementation, review, delivery, branch/PR/release handling, or feature archive. Routes to smaller project-local skills instead of loading all workflow detail."
---

# FrameLean Workflow Router

Use this as the FrameLean project entrypoint. It is intentionally light: route to the smallest project-level skill that fits the request.

## Common Ground Rules

- Work only in the FrameLean repository unless the user explicitly changes scope.
- Read `AGENTS.md` and relevant project docs before non-trivial changes.
- Inspect real source, tests, scripts, config, and Git state before proposing or changing behavior.
- If docs and code disagree, prefer code only when implementation clearly moved beyond stale docs; otherwise surface the conflict.
- Protect `main`; do not do daily development directly on it.
- Do not stage, commit, push, revert, delete, or format unrelated user changes without explicit permission.
- Keep work scoped to the active request.

## Skill Router

Use these project-local skills under `.agents/skills/`:

| User intent | Skill |
| --- | --- |
| Analyze a feature, current module, requirement, interaction chain, logic tree, feature-network node | `framelean-feature-analysis` |
| Write a design report, compare options, define boundaries, propose branch names | `framelean-feature-design` |
| Break an accepted design into executable tasks | `framelean-feature-tasks` |
| Write a test plan or test document; include API checks only when relevant | `framelean-test-plan` |
| Implement confirmed code, tests, scripts, docs, or skill changes | `framelean-implementation` |
| Review diffs, run validation, explain failures, re-run checks | `framelean-review` |
| Prepare commit details, PR description, release description, changelog, bug log, feature archive, final delivery package | `framelean-delivery` |

## Full Workflow

Only run the full chain when the user asks for end-to-end execution:

1. `framelean-feature-analysis`
2. `framelean-feature-design`
3. `framelean-feature-tasks`
4. `framelean-test-plan`
5. branch/worktree setup according to `docs/develop/git-workflow.md`
6. `framelean-implementation`
7. `framelean-review`
8. `framelean-delivery`

Respect the existing project gates: do not move from discussion to branch setup, from test planning to implementation, or from implementation to validation until the user explicitly says `可以`, unless the user already asked for an end-to-end execution in the same turn.

## Documentation Sources

- `docs/README.md`: document map and current-vs-history rules.
- `docs/develop/project-workflow.md`: project execution order.
- `docs/develop/git-workflow.md`: branch, worktree, commit, PR, release, and tag rules.
- `docs/develop/architecture.md`: module and dependency boundaries.
- `docs/develop/test-plan.md`: validation and test surfaces.
