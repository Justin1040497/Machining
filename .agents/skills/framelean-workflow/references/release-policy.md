# Release Policy

Release state is represented by tags on `main`.

## Version Format

Use semantic version tags:

```text
vMAJOR.MINOR.PATCH
```

Examples:

```text
v1.0.0
v1.1.0
v1.1.1
```

## Release Branch

Use `release/vX.Y.Z` when release preparation needs a dedicated branch:

- version updates
- changelog updates
- packaging verification
- final bug fixes
- release notes

If a release is small and already validated on `main`, the release branch may be skipped.

## Hotfix Branch

Use `hotfix/vX.Y.Z` for urgent fixes to already released versions. Keep scope narrow and merge back to `main` before tagging.

## Tagging

Tag from `main` after the release branch or hotfix branch has been merged:

```bash
git switch main
git pull --ff-only origin main
git tag v1.1.0
git push origin v1.1.0
```

Release artifacts and release notes should be traceable to the tag.

## Release Artifacts

Release package names are derived from the semantic version in `pubspec.yaml`
without the Flutter build suffix.

For version `1.1.5+3`, release artifacts should use:

```text
FrameLean-v1.1.5.dmg
FrameLean-v1.1.5-windows-x64.zip
```

The Windows zip should extract into a single top-level directory with the same
stem as the zip file:

```text
FrameLean-v1.1.5-windows-x64/
```
