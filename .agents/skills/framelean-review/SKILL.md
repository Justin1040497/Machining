---
name: framelean-review
description: "Use to review and validate FrameLean changes after implementation or sync. Runs or recommends checks, inspects diffs for scope and architecture risk, explains failures, fixes validation issues when requested, and reports concrete results. Use only inside the FrameLean repository."
---

# FrameLean Review

Review the change and validate the touched surfaces. This skill executes or plans checks; it does not prepare commit/PR/release copy. Use `framelean-delivery` for delivery artifacts.

## Required Context

Inspect `git status --short`, the current branch, changed files, and relevant docs/tests. Read `docs/develop/git-workflow.md` and `docs/develop/test-plan.md` when checks touch Dart/Flutter, release, build, packaging, scripts, or workflow.

## Review Focus

- Business boundary creep.
- Architecture boundary violations.
- Missing tests for changed behavior.
- Broken scripts, packaging, CI, runtime paths, or release assumptions.
- Stale docs caused by the change.
- Unrelated user changes accidentally included.

## Default Checks

For Dart/Flutter changes:

```bash
git ls-files '*.dart' | xargs dart format --set-exit-if-changed
flutter analyze
flutter test
```

Run targeted tests first when they give faster feedback, then broaden as risk grows.

## Additional Checks

- Scripts: syntax check and representative command validation.
- Packaging/runtime: macOS or Windows artifact-layout checks, FFmpeg / FFprobe path checks.
- CI/YAML: YAML validity and workflow path review.
- UI: widget tests plus manual or screenshot verification when visible behavior changes.
- Docs-only/project-skill changes: markdown structure, skill validation, link/path review, and `git diff --check`.

## Reporting

If checks pass, list commands and results. If checks fail, report the failing command, concrete failure, known root cause, fix made or recommended, and re-run result.
