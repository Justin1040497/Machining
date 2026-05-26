# PR and Review Policy

Every PR or MR should be easy to review and safe to merge.

## Before Opening

- Confirm the branch type matches the work.
- Confirm no unrelated files are staged.
- Confirm generated files are intentional.
- Sync with `main` when the branch is stale.
- Run checks that match the touched files.

For Dart/Flutter code, use the commands documented in `docs/develop/git-workflow.md`:

```bash
git ls-files '*.dart' | xargs dart format --set-exit-if-changed
flutter analyze
flutter test
```

## PR Description

Include:

- What changed.
- Why it changed.
- How it was tested.
- Any risk, migration, or follow-up.
- Screenshots or recordings for visible UI changes when practical.

## Merge Preference

Prefer Squash Merge for short-lived branches so `main` remains readable.
