# Agent Instructions

This file is the shared project entry point for AI coding agents working in the FrameLean repository.

## Source of Truth

- Git branch, commit, worktree, PR, and release rules live in `docs/develop/git-workflow.md`.
- Agent-specific Git workflow guidance lives in `.agents/skills/git-workflow/SKILL.md`.
- If these files disagree, follow `docs/develop/git-workflow.md` first and update the stale agent guidance.

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

## Documentation

- Update `docs/` when code changes affect architecture, data models, testing, release flow, user-visible behavior, or developer workflow.
- Keep generated diagrams or exported artifacts out of commits unless the user explicitly asks to update them.
