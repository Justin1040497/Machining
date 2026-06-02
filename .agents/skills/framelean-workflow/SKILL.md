---
name: framelean-workflow
description: Use when working in the FrameLean repository on requirement discussion, bug fixes, new features, architecture cleanup, product direction, branch or worktree setup, test design, implementation, validation, documentation, commit message preparation, PR preparation, release tags, or any non-trivial project workflow. Inspect project docs and actual code; when docs lag behind a clearly advanced implementation, prefer the real project state and mark docs stale.
---

# FrameLean Project Workflow

Use this skill for non-trivial FrameLean work from initial requirement discussion through PR preparation. This is the project workflow skill, not just a Git helper.

## First Checks

Before proposing or changing anything:

1. Read `AGENTS.md`.
2. Read `docs/README.md`, `docs/develop/project-workflow.md`, and any relevant product, architecture, data model, test, or technology docs.
3. Inspect the real project state with targeted file searches and source reads. Do not rely on docs alone.
4. Inspect `git status --short` and `git branch --show-current`; inspect recent history when branch context matters.
5. For Git rules, read `docs/develop/git-workflow.md`.
6. When the solution depends on current framework behavior, APIs, tooling, product practice, or market-standard implementation choices, search official documentation and credible professional sources before recommending a path.

If docs and code disagree, decide whether the code has clearly moved beyond the docs or whether the code is drifting away from a confirmed rule. Prefer actual project state only when the implementation is ahead; otherwise surface the conflict and ask or propose a correction.

## References

- Read `references/requirement-discussion-policy.md` during requirement intake, bug diagnosis framing, feature scoping, architecture cleanup, or product direction discussion.
- Read `references/project-reality-policy.md` whenever docs, current code, or product expectations may disagree.
- Read `references/branch-and-worktree-policy.md` before creating, naming, switching, syncing, or troubleshooting branches and worktrees.
- Read `references/test-design-policy.md` before writing tests or code.
- Read `references/implementation-policy.md` before editing production code, scripts, tests, or docs.
- Read `references/review-and-validation-policy.md` before reviewing, running checks, building, or reporting validation results.
- Read `references/documentation-and-pr-policy.md` before updating docs, changelog, bug logs, syncing latest code, or preparing commit details, PR copy, or release copy.
- Read `references/commit-policy.md` when drafting, splitting, or reviewing commit messages.
- Read `references/release-policy.md` for release branches, hotfix branches, release notes, or tags.

## Workflow Gates

### Gate 1: Requirement And Solution Discussion

Understand the request, the project reality, and the relevant external practice before proposing a final plan.

- Do not simply agree with the user. Challenge weak assumptions and offer stronger product, enterprise, or market-standard alternatives when they fit.
- Present meaningful options with strengths, tradeoffs, cost, risk, testability, maintainability, and product impact.
- Ask boundary questions as needed.
- Do not move to branch setup or execution until the user explicitly says `可以`.

### Gate 2: Branch Or Worktree Setup

Protect `main` and keep task work isolated.

- Do not do daily development work directly on `main`.
- Offer a small set of branch-name options that match the request type.
- Use `worktrees/` when the current working tree contains unrelated active work or another branch needs to stay open.
- After creating or opening the task branch, check whether the remote base has new commits and sync appropriately.

### Gate 3: Test Design

Design tests before implementation.

- Choose unit, widget, integration, regression, build, or manual validation based on the actual change.
- Confirm test boundaries and product behavior with the user.
- Do not write tests until the user explicitly says `可以`.

### Gate 4: Implementation

Implement only the confirmed scope.

- Follow the current project architecture and code style.
- Use the actual codebase as source of truth when docs lag behind a clearly advanced implementation.
- Do not add unrelated features, broad refactors, formatting churn, or generated artifacts.
- Avoid creating very large files; split when responsibilities are separable.
- After implementation, summarize what changed, what did not change, and any uncertain boundary.
- Do not proceed to validation until the user explicitly says `可以`.

### Gate 5: Review And Validation

Run checks that match the touched files and review the business boundary.

- For Dart/Flutter changes, use the commands documented in `docs/develop/git-workflow.md`.
- Add build, script, packaging, or manual checks when the change affects those surfaces.
- If issues appear, explain the issue, cause, fix, and why the fix is appropriate.

### Gate 6: Documentation, Sync, Commit, PR, And Release Preparation

Keep docs and review artifacts current.

- Update docs when behavior, architecture, data models, testing, release flow, user-visible behavior, or developer workflow changes.
- Update `docs/archive/changelog.md`; for bug fixes, add a focused log under `docs/archive/logs/`.
- Sync latest remote code, resolve conflicts if any, and rerun the relevant Gate 5 checks.
- Do not stage, commit, or push unless the user explicitly asks.
- After docs, changelog, sync, and validation are complete, always end a commit-ready task with a final delivery package.
- The final delivery package must include commit details and detailed PR title/description copy using the fixed format in `references/documentation-and-pr-policy.md`.
- When the task involves a release branch, hotfix branch, tag, release notes, release artifacts, update manifest, or distribution workflow, also include release description copy using the fixed format in `references/release-policy.md`.
- Do not invent alternate PR or release description headings such as mixing `概述`, `Summary`, or `Overview`; keep the fixed Chinese headings and order.

## Default Rules

- Protect unrelated user changes.
- Keep branch, commit, docs, and PR behavior consistent with `docs/develop/git-workflow.md`.
- Prefer precise project evidence over generic advice.
- Keep discussion and implementation scoped to the active request.
