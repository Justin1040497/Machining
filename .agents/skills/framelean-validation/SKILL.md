---
name: framelean-validation
description: "Use for FrameLean validation planning and review. Writes validation plans before implementation when needed, reviews diffs after implementation, runs or recommends checks, explains failures, fixes validation issues when requested, and reports concrete results. Use only inside the FrameLean repository."
---

# FrameLean Validation

Validate the changed surface. This skill replaces the old separate test-plan and review skills.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. For validation after implementation, inspect Git state and diffs before running checks.

## Modes

- **Plan mode**: before implementation, write the validation plan for a confirmed feature or `.workspace/plans/` file.
- **Review mode**: after implementation, inspect diffs for scope, architecture, tests, docs, and unrelated changes.
- **Run mode**: execute checks that match the touched files and report results.

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

For docs-only or project-skill changes:

```bash
git diff --check
python3 /Users/leftzhou/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/framelean-skill-name
```

If `quick_validate.py` fails because Python cannot import `yaml`, use Ruby standard-library `YAML` or another structured YAML parser to validate the same frontmatter constraints, and report the fallback. Also scan for stale paths and deleted skill names with `rg`.

## Output Shape

Use Chinese.

```markdown
# 验证结果

## 检查范围

## 命令结果

| 命令 | 结果 | 说明 |
| --- | --- | --- |

## 审查发现

## 未覆盖风险

## 建议下一步
```

If checks fail, report the failing command, concrete failure, known root cause, fix made or recommended, and re-run result.
