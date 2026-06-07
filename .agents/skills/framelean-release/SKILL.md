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

Use `pubspec.yaml`, release scripts, packaging scripts, update manifests, or platform docs only when the release touches those surfaces.

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
