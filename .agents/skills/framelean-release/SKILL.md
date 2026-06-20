---
name: framelean-release
description: "Use to summarize and discuss FrameLean changes for a user-specified version, then produce that version's release document. Scans Git history since the previous relevant tag and current project docs, drafts release notes, asks for confirmation, and writes docs/releases/version/release.md when approved. Use only inside the FrameLean repository."
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

If the gate finds stale script, Action, YAML, or docs wiring, stop and ask whether to fix it first or record it as a known risk. Record the final gate result under `验证与兼容` and unresolved gaps under `已知风险`.

## Workflow

1. Identify the previous relevant tag and state the comparison range.
2. Summarize completed features, fixes, workflow changes, docs changes, validation, and known risks.
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

## 修复与稳定性

## 验证与兼容

## 发布产物

## 已知风险

## 升级与回滚说明

## 关联记录
```

Use `无` or `不适用` when a section does not apply. Do not tag, push, publish, or create release artifacts unless the user explicitly asks.
