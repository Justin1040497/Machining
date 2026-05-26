# Branch Policy

Machining uses a lightweight trunk-based workflow:

```text
short-lived branch -> PR / MR -> main -> release tag
```

`main` is the only long-lived branch. Do not create a permanent `develop` branch unless the project later needs multiple long-running version lines or a fixed integration environment.

## Branch Types

- `feature/<name>`: user-visible features, new business capabilities, or complete new workflows.
- `fix/<name>`: bug fixes and behavior corrections.
- `chore/<name>`: repository structure, tooling, dependencies, CI, scripts, cleanup, or broad refactors.
- `docs/<name>`: documentation-only work.
- `release/vX.Y.Z`: release preparation with version, changelog, packaging, and last-mile fixes.
- `hotfix/vX.Y.Z`: urgent fix for an already released version.

## Naming Rules

- Use lowercase English words, numbers, and hyphens.
- Prefer domain words from the project: `workbench`, `ffmpeg`, `compression`, `settings`, `architecture`, `persistence`.
- Keep the branch name about the change, not the tool or agent.
- If work expands from docs into tracked structure or code changes, re-evaluate the branch type.

## Examples

```text
feature/batch-compression
fix/ffmpeg-path-resolution
chore/codebase-refactor
docs/update-architecture
release/v1.1.0
hotfix/v1.1.1
```
