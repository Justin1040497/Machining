---
name: framelean-delivery
description: "Use for FrameLean delivery closeout after implementation or validation. Checks branch suitability, calibrates current project facts, updates necessary documentation, and returns Markdown commit information plus a concise reviewer-facing PR description. Use only inside the FrameLean repository."
---

# FrameLean Delivery

Prepare a change for handoff by making project facts current and producing commit and PR copy. This skill does not generate formal release documents; use `framelean-release` for that.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol. Always inspect Git status, current branch, changed files, and relevant diffs.

## Branch Suitability

Compare the current branch with the actual change before preparing delivery copy. Treat a detached HEAD, `main`, and every `release/*` branch as unsuitable for normal change delivery. A branch is suitable only when its purpose matches the change and it follows the project workflow: `feature/*`, `fix/*`, `chore/*`, `docs/*`, or `hotfix/*`, using lowercase English letters, digits, and hyphens after the slash.

Choose the prefix from the dominant change intent:

- `feature/*` for new product behavior.
- `fix/*` for non-emergency defect correction.
- `chore/*` for repository governance, migrations, Skills, CI/build maintenance, dependency maintenance, tests, or refactoring without new product behavior.
- `docs/*` for documentation-only work.
- `hotfix/*` only for an urgent production repair.

Never suggest `codex/*`, `main`, or `release/*`. If the current branch is unsuitable or its slug does not represent the change, return exactly one concise branch recommendation and explain why; do not create or switch branches. If it is suitable, do not suggest an alternative and state that the current branch matches the change and can be used directly for the commit.

## Documentation Calibration

Identify which facts the changed files can affect, then inspect only those current-fact documents. Typical targets are root `CONTEXT.md` / `context/` for cross-component facts, the target component README / CONTEXT, `changelog/<component>.md`, `docs/releases/<component>/`, or `.agents/skills/` entries. Desktop-specific decisions, current work, and lessons remain under `desktop-client/docs/`; cross-component decisions use root `docs/decisions/`. Use `rg` for stale names and paths instead of opening the entire documentation tree.

## Packaging Freshness Check

Run a Desktop Client packaging and update-config freshness check only when the change affects Desktop release, CI, installer, update, signing, notarization, packaging, or related workflow facts. Do not apply this gate to an unrelated Backend, FLL, or FEngine delivery.

Inspect the current source of truth instead of trusting existing docs:

```text
.github/workflows/*.yml
scripts/README.md
scripts/release/*
desktop-client/macos/Runner/Info.plist
desktop-client/macos/Runner/Configs/*.xcconfig
installer/windows/*
tools/sign_windows_update.dart
```

Use targeted `rg` searches for update/signing variables such as `FRAMELEAN_UPDATE`, `FRAMELEAN_SPARKLE`, `SUPublicEDKey`, `SUFeedURL`, `FRAMELEAN_RELEASE`, `notarization`, `sign_update`, and artifact paths.

Check at minimum:

- GitHub Actions pass required Variables / Secrets / env values into the release scripts.
- Local release commands and docs match the current script parameters, env names, artifact names, and output paths.
- macOS manual DMG updates inject `FRAMELEAN_UPDATE_BASE_URL` from local and CI packaging entry points; Sparkle `SUFeedURL` / `SUPublicEDKey` is checked only when the Sparkle route is explicitly enabled.
- Windows update base URL, trusted key ids, public keys, private-key-file signing, and `*.update.json` generation are wired from local and CI packaging entry points.
- Missing release configuration fails closed instead of producing artifacts that look releasable but lack update configuration.

If the check finds drift, update the stale script, workflow, YAML, or docs before final delivery, or explicitly report the blocker. Do not copy routine packaging checks into the PR description; include only a material unresolved risk under optional notes.

## Update Rules

- Update `changelog/<component>.md` only for development process, architecture adjustments, and technical changes.
- Update `docs/releases/<component>/` only for versioned, dated, user-visible release facts or an existing next-version user-visible draft.
- Update root `docs/decisions/` for cross-component decisions; update `desktop-client/docs/decisions/` and `desktop-client/docs/work/decisions.md` for Desktop-only decisions.
- Update `desktop-client/docs/lessons.md` only for reusable Desktop Client lessons; do not invent equivalent files for other components.
- Keep temporary task status under the ignored root `.workspace/`.
- Update `AGENTS.md`, `CLAUDE.md`, `README.md`, or `.agents/skills/` when agent workflow or developer workflow changed.
- Do not create `docs/archive/`, `docs/features/`, `docs/plans/`, daily logs, or one-bug-one-file notes.
- Before handoff, scan uploadable changed files for prohibited external reference-project or competitor terms and keep any research only in ignored `.workspace/`.

## Delivery Copy

Return the branch result first, then always return both delivery sections in Markdown:

````markdown
## 分支建议

当前分支 `release/v1.2.1` 不适合本次工程治理改动，建议使用：

```text
chore/monorepo-normalization
```

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
## Summary

- 用一段短文或 2～5 个 bullet 说明改了什么，以及不明显时为什么要改。
- 需要时直接附 `Closes #...` 或相关设计文档链接。

## Notes

- 仅保留评审者必须知道的迁移、兼容性、风险、截图或特殊决策；没有就删除整个章节。
```
````

The branch block above demonstrates the unsuitable case. For a suitable branch, replace it with a short `## 分支` confirmation that names the current branch and says it can be used directly for the commit; omit any alternative branch name.

Keep ordinary PR bodies around 5～15 lines. Scale detail with review risk, not diff size or a fixed section count. Do not include a `Verification` section, routine test commands, file lists, commit summaries, documentation inventories, empty headings, or generic rollback boilerplate. Link to issues, decisions, changelogs, or CI instead of copying their content.

Do not run `git add`, `git commit`, `git push`, create tags, or open PRs unless the user explicitly asks.
