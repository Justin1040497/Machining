# Agent Instructions

This file is the shared project entry point for AI coding agents working in the FrameLean repository.

## Source of Truth

- Full project execution workflow rules live in `docs/develop/project-workflow.md`.
- Git branch, commit, worktree, PR, and release rules live in `docs/develop/git-workflow.md`.
- Agent-specific project workflow guidance lives in `.agents/skills/framelean-workflow/SKILL.md`.
- If workflow docs and the current project implementation disagree, prefer the real project state only when implementation has clearly moved beyond stale docs; then update the stale docs.
- If Git-specific files disagree, follow `docs/develop/git-workflow.md` first and update stale agent guidance.

## Tool Compatibility

- Codex reads `AGENTS.md` as the repository instruction file.
- Claude Code reads `CLAUDE.md`; this repository keeps `CLAUDE.md` as a thin adapter that imports this file.
- Shared agent workflows belong under `.agents/`.
- Tool-specific settings belong only in the matching tool directory, such as `.codex/` or `.claude/`, when that tool actually needs them.

## Git Workflow

- `main` is the only long-lived trunk branch.
- Do not commit daily development work directly to `main`.
- Use short-lived branches: `feature/*`, `fix/*`, `chore/*`, `docs/*`, `release/*`, or `hotfix/*`.
- Use `worktrees/` for local Git worktrees; this directory is intentionally ignored.
- Do not stage, commit, revert, delete, or format unrelated user changes without explicit permission.
- Before opening or preparing a merge, run the checks required by the touched files. For Dart/Flutter changes, use the commands documented in `docs/develop/git-workflow.md`.

## Project Workflow

- Discuss requirements, alternatives, risks, and boundaries before implementation.
- Inspect both project docs and actual code before proposing or changing behavior.
- For non-trivial code changes, design tests before implementation.
- Keep implementation scoped to the confirmed requirement and current architecture.
- Validate changes, update docs, and prepare commit / PR copy according to `docs/develop/project-workflow.md`.

## Documentation

- Update `docs/` when code changes affect architecture, data models, testing, release flow, user-visible behavior, or developer workflow.
- Keep generated diagrams or exported artifacts out of commits unless the user explicitly asks to update them.
