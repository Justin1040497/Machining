---
name: framelean-release
description: "Use to summarize and discuss FrameLean changes for a user-specified version, then produce a concise user-facing release document. Scans Git history and current packaging facts, drafts release notes, asks for confirmation, and writes docs/releases/version/release.md when approved. Use only inside the FrameLean repository."
---

# FrameLean Release

Create a release document for a user-specified version. This skill is for version narrative and release notes, not commit or PR copy.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol.

## Version Rule

The user must specify the target version, such as `v1.1.6`. If no version is specified, ask for it before scanning or writing.

## Scan Scope

Use targeted Git and docs reads:

```text
git tag --sort=-creatordate
git log previous-tag..HEAD
git diff --stat previous-tag..HEAD
CHANGELOG.md
docs/releases/
docs/decisions/
docs/lessons.md
docs/work/
```

For every release document, also inspect packaging and update surfaces before claiming release readiness:

```text
pubspec.yaml
.github/workflows/*.yml
scripts/README.md
scripts/release/*
macos/Runner/Info.plist
macos/Runner/Configs/*.xcconfig
installer/windows/*
tool/sign_windows_update.dart
```

Use additional server/Admin files only when the release touches self-hosted update metadata, release package requirements, appcast generation, upload flows, or download-ticket behavior.

## Packaging Freshness Gate

Before drafting or writing the release document, compare the current packaging source files against the release claims. Do not rely on older release docs as proof that packaging still works.

Check at minimum:

- macOS and Windows GitHub Actions call the canonical release scripts and pass the required Variables / Secrets / env values.
- Local release commands, CI workflow steps, artifact names, and upload paths match the current script outputs.
- macOS manual DMG update expectations, `FRAMELEAN_UPDATE_BASE_URL` injection, DMG download/manual install behavior, and optional Sparkle `SUFeedURL` / `SUPublicEDKey` / `sign_update` metadata are represented accurately.
- Windows update base URL, trusted release key ids, public keys, private-key-file signing, installer target, and `*.update.json` generation are represented accurately.
- Missing release configuration fails closed instead of producing artifacts that look releasable but lack update configuration.

If the gate finds stale script, Action, YAML, or docs wiring, stop and ask whether to fix it first or record it as a known risk. Keep routine gate results out of the public release narrative; record only unresolved, user-relevant compatibility or packaging risks.

## Workflow

1. Identify the previous relevant tag and state the comparison range.
2. Summarize user-facing features, important fixes, compatibility changes, and known risks. Keep workflow, documentation, and routine validation details in their source records.
3. Ask focused questions when version scope, included changes, platform support, release artifacts, or known risks are unclear.
4. Draft release copy in the conversation or `.workspace/release-drafts/vX.Y.Z.md` during discussion.
5. After user confirmation, write:

```text
docs/releases/vX.Y.Z/release.md
```

## Release Document Shape

Use Chinese unless the user asks otherwise.

```markdown
# vX.Y.Z Release

## 版本摘要

## 主要变更

## 重要修复

## 兼容性与已知问题

## 完整记录
```

Keep the summary to one short paragraph, then use 3～6 user-facing bullets per relevant section. Omit empty sections instead of writing `无` or `不适用`. Do not paste test logs, internal workflow changes, file inventories, packaging checklists, artifact lists already visible on the release page, or generic rollback instructions. Link to the full changelog and detailed migration documentation when needed. Do not tag, push, publish, or create release artifacts unless the user explicitly asks.
