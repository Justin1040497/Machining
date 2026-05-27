# Documentation And PR Policy

Use this policy at the final workflow stage.

## Documentation Updates

Update docs when a change affects:

- Architecture or module boundaries.
- Data models, persistence, migrations, or compatibility values.
- Testing, build, release, or developer workflow.
- User-visible behavior or product scope.
- Runtime packaging or external distribution requirements.

Prefer current docs under `docs/develop/`, `docs/product/`, and `docs/reference/` for lasting facts. Use `docs/plans/` and `docs/archive/` for history only.

## Change Records

Every commit-ready change must update:

```text
docs/archive/changelog.md
```

Bug fixes must also create or update a focused archive log:

```text
docs/archive/logs/YYYY-MM-DD-<bug-slug>.md
```

Use the existing changelog shape:

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

## Sync Before Final Recommendation

After docs are updated:

1. Fetch or pull the latest remote base in a way that preserves the task branch.
2. Resolve conflicts if they appear.
3. Re-run the relevant checks from `review-and-validation-policy.md`.

## Commit And PR Preparation

Do not run `git add`, `git commit`, or `git push` unless the user explicitly asks.

When ending the task, provide:

- Scoped file summary.
- Checks run and results.
- Commit message candidates.
- PR title and description when a PR is likely.

Commit candidates should use Conventional Commits with Chinese text after the colon, for example:

```text
feat(workbench): 添加批量压缩任务配置
fix(ffmpeg): 修复路径解析失败问题
docs(workflow): 更新项目执行流程
```

PR descriptions should include:

- Summary.
- Why.
- Testing.
- Risks or review notes.
