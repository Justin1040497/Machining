---
name: git-workflow
description: Use when working in the FrameLean repository on Git branch selection, commit messages, staging scope, worktree use, pull/rebase decisions, PR preparation, release tags, or deciding whether changes belong in feature, fix, chore, docs, release, or hotfix branches. Always read docs/develop/git-workflow.md first and protect unrelated user changes.
---

# FrameLean Git Workflow

Use this skill for Git operations and Git guidance in the FrameLean repository.

## First Checks

Before recommending or performing Git actions:

1. Read `docs/develop/git-workflow.md`.
2. Inspect `git status --short`.
3. Inspect `git branch --show-current`.
4. If branch history matters, inspect recent commits with `git log --oneline -8`.

If the working tree has unrelated changes, do not stage, revert, format, or delete them. Explain the boundary and either continue with scoped files, use a worktree, or ask before touching anything ambiguous.

## References

- Read `references/branch-policy.md` when choosing or naming a branch.
- Read `references/branch-creation-troubleshooting.md` when branch creation fails or Git reports `cannot lock ref`.
- Read `references/commit-policy.md` when writing, splitting, or reviewing commits.
- Read `references/change-record-policy.md` before preparing, staging, or making a commit.
- Read `references/worktree-policy.md` when the current branch has active work or the user needs parallel tasks.
- Read `references/pr-review-policy.md` when preparing a PR or merge summary.
- Read `references/release-policy.md` when preparing release branches or tags.

## Default Rules

- `main` is the only long-lived trunk branch.
- Do not commit daily development work directly to `main`.
- Prefer short-lived branches merged back by PR or MR.
- Keep branch names lowercase, English, numeric, and hyphen-separated.
- If branch creation fails with `cannot lock ref`, diagnose real ref path conflicts separately from sandbox or permission failures before proposing a new branch name.
- Keep commits logically scoped; avoid mixing unrelated behavior, formatting, generated files, and documentation churn.
- Use Conventional Commits style unless the user or repository history clearly requires a different format.
- Before every commit, update `docs/archive/changelog.md` for the scoped change.
- For bug-fix commits, also create a matching `docs/archive/logs/YYYY-MM-DD-<bug-slug>.md` record.
- Include required changelog and bug-log files in the same commit as the related change.
- Use `worktrees/` for local worktrees because the directory is ignored by this repository.
- Before merge, run the checks required by the affected files. For Dart/Flutter code, use the commands documented in `docs/develop/git-workflow.md`.
