---
name: framelean-delivery
description: "Use for FrameLean delivery work: lightweight commit/PR/release copy, final delivery packages, changelog and bug-log guidance, feature-network archive updates, branch/sync status, and release descriptions. Use when the user asks for commit information, PR description, release description, final handoff, feature archive, changelog entry, or Git delivery details. Use only inside the FrameLean repository."
---

# FrameLean Delivery

Prepare delivery artifacts without forcing the full project workflow. This skill has two modes.

## Mode Selection

- **Brief mode**: user only wants commit details, PR copy, release description, or a final summary. Inspect the diff and relevant workflow templates; do not require feature-network archive.
- **Archive mode**: user asks to archive a completed feature or prepare the full final delivery package. Update or draft feature-network records, changelog, bug log if needed, commit details, PR description, and release description when relevant.

Do not run `git add`, `git commit`, `git push`, create tags, or open PRs unless the user explicitly asks.

## Required Context

Always inspect `git status --short`, current branch, changed files, and relevant diffs. Read `docs/develop/git-workflow.md` for branch, commit, PR, and release rules. Read feature docs and source only as needed to explain the actual change.

## Feature Archive

Use archive mode when the request involves "功能网", "归档功能", release archival, or a completed feature record.

Preferred location:

```text
docs/features/feature-network/
  index.md
  modules/{module}.md
  trace/{version-or-date}.md
```

Archive output should include:

- Global node table and network graph updates.
- Module local network updates: dependencies, data/event flow, lifecycle/subscription notes when relevant.
- Trace snapshot for release or explicit archive points.
- Branch and delivery status: branch name, base, changed-file scope, validation status, changelog status.

Do not invent node numbers. Use `analysis.md` when present; otherwise inspect the accepted feature docs and current source.

## Changelog And Bug Logs

Every commit-ready change should update or draft `docs/archive/changelog.md`. Bug fixes should also create or draft:

```text
docs/archive/logs/YYYY-MM-DD-{bug-slug}.md
```

If the user asks only for copy and not file edits, provide the exact suggested entry instead of editing files.

## Commit Details

Use Conventional Commits with English type/scope and Chinese summary:

```text
<type>(scope): 中文摘要
```

Return:

```markdown
## 提交详情

推荐提交：
`<type>(scope): 中文摘要`

提交范围：
- <文件或模块范围>

提交正文：
- 需要 / 不需要
- 原因：<原因>

建议正文：
<仅在需要时填写>
```

## PR Description

Use this exact order:

```markdown
## 变更概览

- ...

## 背景与目标

- ...

## 实现详情

- ...

## 验证结果

- ...

## 风险与回滚

- ...

## 文档与变更记录

- ...

## 评审重点

- ...
```

## Release Description

Include release copy when the task touches a `release/*` branch, `hotfix/*` branch, tag, Release Notes, release artifacts, update manifest, distribution workflow, or the user asks for release description.

Use this exact order:

```markdown
## 版本摘要

- ...

## 主要变更

- ...

## 验证与兼容

- ...

## 发布产物

- ...

## 已知风险

- ...

## 升级与回滚说明

- ...

## 关联记录

- ...
```

Keep all headings. Use `无` or `不适用` when a section does not apply.
