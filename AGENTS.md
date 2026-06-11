# Agent Instructions

This file is the shared project entry point for AI coding agents working in the FrameLean repository.

## Source of Truth

- Project execution, Git branch, commit, worktree, PR, and release rules live in `docs/develop/workflow.md`.
- FrameLean project skill routing and shared pre-read rules live in `.agents/skills/README.md`.
- Agent-specific project workflow routing lives in `.agents/skills/framelean-workflow/SKILL.md`.
- Specialized project skills live under `.agents/skills/framelean-*`; keep them project-local unless the user explicitly asks for a user-level or global Skill.
- If workflow docs and the current project implementation disagree, prefer the real project state only when implementation has clearly moved beyond stale docs; then update the stale docs.
- If Git-specific guidance disagrees, follow `docs/develop/workflow.md` first and update stale agent guidance.

## Tool Compatibility

- Codex reads `AGENTS.md` as the repository instruction file.
- Claude Code reads `CLAUDE.md`; this repository keeps `CLAUDE.md` as a thin adapter that imports this file.
- Shared agent workflows belong under `.agents/`.
- Tool-specific settings belong only in the matching tool directory, such as `.codex/` or `.claude/`, when that tool actually needs them.
- Project-level Skills for FrameLean belong under `.agents/skills/`; do not create FrameLean workflow Skills in user-level skill directories unless explicitly requested.

## Git Workflow

- `main` is the only long-lived trunk branch.
- Do not commit daily development work directly to `main`.
- Use short-lived branches: `feature/*`, `fix/*`, `chore/*`, `docs/*`, `release/*`, or `hotfix/*`.
- Use `worktrees/` for local Git worktrees; this directory is intentionally ignored.
- Do not stage, commit, revert, delete, or format unrelated user changes without explicit permission.
- Before opening or preparing a merge, run the checks required by the touched files. For Dart/Flutter changes, use the commands documented in `docs/develop/workflow.md`.

## Project Workflow

- Discuss requirements, alternatives, risks, and boundaries before implementation.
- Inspect both project docs and actual code before proposing or changing behavior.
- For non-trivial code changes, design tests before implementation.
- Keep implementation scoped to the confirmed requirement and current architecture.
- Validate changes, update docs, and prepare commit / PR copy according to `docs/develop/workflow.md`.

## Documentation

- Update `docs/` when code changes affect architecture, data models, testing, release flow, user-visible behavior, developer workflow, version facts, decisions, or reusable lessons.
- Do not create `docs/archive/`, `docs/features/`, `docs/plans/`, or `docs/product/roadmap.md`.
- Keep generated diagrams or exported artifacts out of commits unless the user explicitly asks to update them.


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->
