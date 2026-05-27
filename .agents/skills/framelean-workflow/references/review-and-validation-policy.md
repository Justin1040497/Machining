# Review And Validation Policy

Use this policy after implementation and after syncing latest code.

## Review Focus

Review for:

- Business boundary creep.
- Architecture boundary violations.
- Missing tests for changed behavior.
- Broken scripts, packaging, or release assumptions.
- Stale docs caused by the change.
- Unrelated user changes accidentally included.

Use a language-specific or review skill when available and useful.

## Required Checks

For Dart/Flutter changes, use the checks documented in `docs/develop/git-workflow.md`:

```bash
git ls-files '*.dart' | xargs dart format --set-exit-if-changed
flutter analyze
flutter test
```

Run targeted tests first when they give faster feedback, then broaden as risk grows.

## Additional Checks

Add checks when relevant:

- Build scripts for `scripts/` changes.
- macOS or Windows build commands for packaging/runtime changes.
- YAML parsing or workflow validation for CI changes.
- Manual UI checks or screenshots for visible workbench changes.
- Runtime layout checks for FFmpeg / FFprobe packaging changes.

## Reporting

If checks pass, report what was run and the result.

If checks fail, report:

- The failing command.
- The concrete failure.
- The root cause when known.
- The fix made.
- The re-run result.
