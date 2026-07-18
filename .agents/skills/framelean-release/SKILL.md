---
name: framelean-release
description: "Use to summarize and discuss FrameLean changes for a user-specified component and version, then produce a concise user-facing release document under docs/releases/component/version. Resolves evidence and readiness checks per Desktop Client, Backend, FLL, or FEngine instead of assuming one shared release pipeline. Use only inside the FrameLean repository."
---

# FrameLean Release

Create a release document for a user-specified component and version. This skill is for version narrative and release notes, not commit or PR copy.

## Shared Context

Read `.agents/skills/README.md` first and follow the shared pre-read protocol.

## Version Rule

The user must specify the target component and version, such as Desktop Client `v1.1.6` or FLL `v0.2.0`. If either is missing, ask before scanning or writing. Use component manifests only to verify the requested version:

- Desktop Client: `desktop-client/pubspec.yaml`, excluding the `+build` suffix from the public version.
- FLL: `fll/Cargo.toml` workspace package version.
- FEngine: `fengine/Cargo.toml` package version.
- Backend: treat `backend/pom.xml` revision and `backend/admin-web/package.json` version as implementation facts, not automatically as the public FrameLean Backend release version.

## Scan Scope

Use targeted Git and component docs reads:

```text
changelog/<component>.md
docs/releases/<component>/
component README / CONTEXT / manifest
relevant implementation, tests, decisions, and workflows
```

Use Git tags and comparison ranges only when the repository history proves that the tag series belongs to the target component. The root repository history and existing `vX.Y.Z` tags primarily describe Desktop Client releases; do not use them as FLL, FEngine, or Backend history without explicit component tag evidence.

For Desktop Client releases, inspect packaging and update surfaces before claiming release readiness:

```text
desktop-client/pubspec.yaml
.github/workflows/*.yml
scripts/README.md
scripts/release/*
desktop-client/macos/Runner/Info.plist
desktop-client/macos/Runner/Configs/*.xcconfig
installer/windows/*
tools/sign_windows_update.dart
```

For Backend releases, inspect `backend/pom.xml`, affected modules, `backend/admin-web/package.json`, Docker/configuration, and `.github/workflows/backend.yml`. For FLL releases, inspect the workspace manifest, affected crates, Runtime Schema exporters/baselines, and `.github/workflows/fll.yml`. For FEngine releases, inspect its standalone manifest, CLI entry/tests, FLL path dependencies, and `.github/workflows/fengine.yml`.

## Packaging Freshness Gate

For Desktop Client only, compare the current packaging source files against the release claims before drafting or writing. Do not rely on older release docs as proof that packaging still works.

Check at minimum:

- macOS and Windows GitHub Actions call the canonical release scripts and pass the required Variables / Secrets / env values.
- Local release commands, CI workflow steps, artifact names, and upload paths match the current script outputs.
- macOS manual DMG update expectations, `FRAMELEAN_UPDATE_BASE_URL` injection, DMG download/manual install behavior, and optional Sparkle `SUFeedURL` / `SUPublicEDKey` / `sign_update` metadata are represented accurately.
- Windows update base URL, trusted release key ids, public keys, private-key-file signing, installer target, and `*.update.json` generation are represented accurately.
- Missing release configuration fails closed instead of producing artifacts that look releasable but lack update configuration.

For other components, apply an equivalent component-specific readiness gate without running Desktop packaging checks. If a gate finds stale script, Action, manifest, schema, or docs wiring, stop and ask whether to fix it first or record it as a known risk. Keep routine gate results out of the public release narrative; record only unresolved, user-relevant compatibility or packaging risks.

## Workflow

1. Identify the component-specific evidence range; use a previous tag only when it demonstrably belongs to that component.
2. Summarize user-facing features, important fixes, compatibility changes, and known risks. Keep workflow, documentation, and routine validation details in their source records.
3. Ask focused questions when version scope, included changes, platform support, release artifacts, or known risks are unclear.
4. Draft release copy in the conversation or `.workspace/release-drafts/vX.Y.Z.md` during discussion.
5. After user confirmation, write:

```text
docs/releases/<component>/vX.Y.Z/release.md
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

Use only FrameLean product and component terminology in tracked release documents. Keep external reference-project or competitor research under ignored `.workspace/` and never link it from a release record.
