# Project Reality Policy

Use this policy whenever docs, code, current product expectations, or user requirements might disagree.

## Sources To Inspect

Prefer targeted inspection over broad reading:

- `docs/README.md` for the doc map and current-vs-history rules.
- `docs/develop/architecture.md` for layer boundaries.
- `docs/develop/technology-stack.md` for current dependencies and platform scope.
- `docs/develop/data-model.md` for persistence and model changes.
- `docs/develop/test-plan.md` for validation scope.
- `lib/`, `test/`, `scripts/`, `pubspec.yaml`, platform folders, and CI files for actual implementation.

## Conflict Handling

When docs and code disagree:

- If code has clearly moved beyond docs, use the real code as the working source of truth and mark the docs as stale.
- If code appears to violate a current architecture or workflow rule, surface the risk and propose correction instead of silently following the code.
- If intent is unclear, explain the conflict and ask for the decision before irreversible changes.
- If the task reaches the documentation stage, update stale docs to match the accepted implementation.

## Practical Checks

Use project evidence such as:

```bash
rg --files
rg -n "<domain-term>"
git status --short
git branch --show-current
```

For Flutter/Dart architecture, trace the dependency path before editing:

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

Do not let old `plans/` or `archive/` material override current source code or current `develop/` docs.
