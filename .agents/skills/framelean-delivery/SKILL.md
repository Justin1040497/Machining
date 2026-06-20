---
name: framelean-delivery
description: "Use for FrameLean delivery closeout after implementation or validation. Calibrates current project facts across important root documents and docs, updates or drafts necessary documentation, and returns Markdown commit information plus Markdown PR description. Use only inside the FrameLean repository."
---

# FrameLean Delivery

Prepare a change for handoff by making project facts current and producing commit and PR copy. This skill does not generate formal release documents; use `framelean-release` for that.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Always inspect Git status, current branch, changed files, and relevant diffs.

## Documentation Calibration

Scan current-fact documents before writing delivery copy:

```text
CONTEXT.md
README.md
AGENTS.md
CLAUDE.md
CHANGELOG.md
docs/README.md
docs/work/active.md
docs/work/backlog.md
docs/work/decisions.md
docs/releases/*
docs/decisions/*
docs/lessons.md
docs/develop/*
docs/reference/*
.agents/skills/*
```

Do not rewrite everything. Use targeted reads and `rg` to find stale facts, old paths, deleted skill names, changed commands, changed architecture, changed release facts, or changed workflow rules.

## Packaging Freshness Check

Before writing delivery copy, run a lightweight packaging and update-config freshness check. This is required for release, CI, installer, update, signing, notarization, packaging, or workflow changes, and still should be briefly considered for other changes.

Inspect the current source of truth instead of trusting existing docs:

```text
.github/workflows/*.yml
scripts/README.md
scripts/release/*
macos/Runner/Info.plist
macos/Runner/Configs/*.xcconfig
installer/windows/*
tool/sign_windows_update.dart
```

Use targeted `rg` searches for update/signing variables such as `FRAMELEAN_UPDATE`, `FRAMELEAN_SPARKLE`, `SUPublicEDKey`, `SUFeedURL`, `FRAMELEAN_RELEASE`, `notarization`, `sign_update`, and artifact paths.

Check at minimum:

- GitHub Actions pass required Variables / Secrets / env values into the release scripts.
- Local release commands and docs match the current script parameters, env names, artifact names, and output paths.
- macOS Sparkle `SUFeedURL` / `SUPublicEDKey` injection is wired from local and CI packaging entry points.
- Windows update base URL, trusted key ids, public keys, private-key-file signing, and `*.update.json` generation are wired from local and CI packaging entry points.
- Missing release configuration fails closed instead of producing artifacts that look releasable but lack update configuration.

If the check finds drift, update the stale script, workflow, YAML, or docs before final delivery, or explicitly report the blocker. Mention the check result in `验证结果` or `风险与回滚`.

## Update Rules

- Update `CHANGELOG.md` when the change is worth version-level recall.
- Update `docs/releases/` when a stable shipped design or workflow fact changed.
- Update `docs/decisions/` and `docs/work/decisions.md` when an important durable decision was made.
- Update `docs/lessons.md` when the work produced a reusable lesson.
- Update `docs/work/active.md` or `docs/work/backlog.md` when task status changed.
- Update `AGENTS.md`, `CLAUDE.md`, `README.md`, or `.agents/skills/` when agent workflow or developer workflow changed.
- Do not create `docs/archive/`, `docs/features/`, `docs/plans/`, daily logs, or one-bug-one-file notes.

## Delivery Copy

Always return both sections in Markdown:

````markdown
## Commit 信息

```text
type(scope): 中文摘要
```

提交范围：

- ...

提交正文：

- 需要或不需要
- 原因：...

## PR Description

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
````

Do not run `git add`, `git commit`, `git push`, create tags, or open PRs unless the user explicitly asks.
