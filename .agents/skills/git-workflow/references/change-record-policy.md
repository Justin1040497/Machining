# Change Record Policy

Use this policy before preparing, staging, or making a commit in FrameLean.

## Required Records

Every commit must update:

```text
docs/archive/changelog.md
```

Bug-fix commits must also create or update a focused archive log under:

```text
docs/archive/logs/YYYY-MM-DD-<bug-slug>.md
```

Keep these record files in the same commit as the related source, test, or documentation changes.

## What Counts As A Bug Fix

Treat a change as a bug fix when any of these are true:

- The branch is `fix/*` or `hotfix/*`.
- The commit type is `fix:`.
- The main purpose is correcting an exception, regression, platform compatibility issue, data error, build failure, broken workflow, or wrong user-visible behavior.

Do not create a bug archive log for pure formatting, routine docs, test-only coverage, refactors without behavior correction, or chore work unless the chore directly fixes a broken process.

## Changelog Entry

Use the existing changelog format:

```text
YYYY-MM-DD / vX.Y.Z / Summary
- added
  - New capability or user-visible addition.
- changed
  - Behavior, architecture, workflow, or maintenance change.
- fixed
  - Bug fix or corrected behavior.
- verified
  - Checks, tests, builds, or manual validation performed.
```

Write concise release-note style bullets. Do not paste full implementation notes, stack traces, or long investigation history into the changelog.

If there is no explicit release version for the change, use the current project version from a source such as `pubspec.yaml` or follow the existing unreleased heading pattern in `docs/archive/changelog.md`.

## Bug Archive Log Template

Use a short slug in lowercase English words separated by hyphens:

```text
docs/archive/logs/2026-05-26-ffprobe-duration-parsing.md
```

Start new bug logs with this shape:

```markdown
# 2026-05-26 Ffprobe Duration Parsing

## Problem Summary

Describe the user-facing failure, failing command, failing test, or observed symptom.

## Root Cause

Explain the specific cause once known. Keep speculation out unless clearly marked.

## Fix

Summarize the implementation change and any compatibility impact.

## Modified Files

- `path/to/file.dart`

## Validation

- `flutter analyze`
- `flutter test`
```

Archive logs are evidence for future maintenance. They can include more detail than the changelog, but should stay focused on the bug being fixed.

## Pre-Commit Checklist

Before staging a commit:

1. Inspect the scoped diff and identify the commit type.
2. Update `docs/archive/changelog.md` with the concise entry for this change.
3. If this is a bug fix, add the matching file under `docs/archive/logs/`.
4. Stage only the source files, tests, documentation, and record files that belong to the same logical change.
5. Leave unrelated user edits unstaged.
