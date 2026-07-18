# FrameLean Agent Instructions

This file is the shared project entry point for AI coding agents.

## Sources of Truth

- Current project facts: `CONTEXT.md`, `context/`, and `docs/README.md`.
- Desktop Client workflow: `desktop-client/docs/develop/workflow.md`.
- Desktop Client facts: `desktop-client/README.md`, `desktop-client/CONTEXT.md`, `desktop-client/pubspec.yaml`, then relevant docs, source, and tests.
- Backend facts: `backend/README.md`, `backend/CONTEXT.md`, `backend/pom.xml`, then the affected Maven module or `admin-web/package.json`.
- FLL facts: `fll/README.md`, `fll/CONTEXT.md`, `fll/Cargo.toml`, then the affected crate, schemas, and tests.
- FEngine facts: `fengine/README.md`, `fengine/CONTEXT.md`, `fengine/Cargo.toml`, then `fengine/src/` and the FLL APIs it uses.
- Protocol facts: `protocol/README.md`, `protocol/v1/README.md`, and `context/protocol.md`; Runtime Schema remains owned by FLL.
- Project Skill routing and shared pre-read rules: `.agents/skills/README.md`.
- Agent workflow router: `.agents/skills/framelean-workflow/SKILL.md`.
- Specialized project Skills: `.agents/skills/framelean-*`.

When docs and implementation disagree, verify the real project state and update stale current-fact documentation. Follow `desktop-client/docs/develop/workflow.md` for desktop-specific delivery conflicts.

## Repository Boundaries

- FrameLean project Skills belong under `.agents/skills/`; tool-specific settings belong only in that tool's directory.
- `CLAUDE.md` remains a thin adapter to this shared instruction file.
- Preserve unrelated user changes. Do not stage, commit, push, revert, delete, or format them.
- Use short-lived `feature/*`, `fix/*`, `chore/*`, `docs/*`, `release/*`, or `hotfix/*` branches; do not commit daily work directly to `main`.
- Use the ignored root `.workspace/` for temporary plans, reports, and release drafts. Do not create component-local `.workspace/` directories.
- Keep external reference-project and competitor research only in `.workspace/`; never copy those brand comparisons into Git-uploadable files.

## Working Rules

- Discuss non-trivial requirements, alternatives, risks, and boundaries before implementation unless the user requests direct end-to-end execution.
- Inspect relevant docs, implementation, tests, scripts, and configuration before changing behavior.
- Make the smallest coherent change that satisfies the confirmed requirement and current architecture.
- Run checks proportionate to the touched files; use `desktop-client/docs/develop/workflow.md` for Dart / Flutter requirements and the component manifest for other stacks.
- Update `docs/` when a change affects current architecture, data models, workflow, release facts, user-visible behavior, durable decisions, or reusable lessons.
- Keep formal release records under `docs/releases/<component>/` and development changes under `changelog/<component>.md`; never mix those responsibilities in one file.
- Preserve Backend modules from the actual `backend/pom.xml`, keep FLL and FEngine as separate Cargo projects, and do not define protocol fields or future process modules without real implementation evidence.
- Keep generated diagrams, screenshots, exports, local outputs, and temporary execution artifacts out of commits unless explicitly requested.
