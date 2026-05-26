# Commit Policy

Use a Conventional Commits style that matches `docs/develop/git-workflow.md`.

## Format

```text
<type>(optional-scope): <summary>
```

Use an imperative, concise English summary.

## Types

- `feat`: user-visible feature.
- `fix`: bug fix.
- `docs`: documentation.
- `refactor`: internal code restructuring without intended behavior change.
- `test`: tests only.
- `chore`: tooling, repo maintenance, generated metadata, or housekeeping.
- `build`: build system or dependency changes.
- `ci`: CI configuration.

## Examples

```text
feat(workbench): add batch compression import
fix(ffmpeg): resolve bundled binary lookup
refactor(domain): split compression policy models
docs: update architecture workflow
test: cover task queue pause behavior
```

## Splitting Rules

- Split commits by logical behavior or project boundary.
- Keep pure formatting separate when it touches many files.
- Do not mix generated files with manual source edits unless generation is the point of the commit.
- Do not include unrelated user edits in the same commit.

## Commit Body

Add a body when the change has non-obvious motivation, migration risk, compatibility impact, or test notes.
