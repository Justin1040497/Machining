#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

required=(
  .git
  desktop-client
  backend/pom.xml
  fll/Cargo.toml
  fengine/Cargo.toml
  protocol/v1/README.md
  dependencies/ffmpeg
  dependencies/qmc
  docs/releases
  changelog
  legal
)

for path_name in "${required[@]}"; do
  if [[ ! -e "$path_name" ]]; then
    echo "error: required path is missing: $path_name" >&2
    exit 1
  fi
done

forbidden=(
  desktop-client/.github
  desktop-client/scripts
  desktop-client/tool
  desktop-client/installer
  desktop-client/legal
  desktop-client/third_party
  desktop-client/CHANGELOG.md
  desktop-client/linux
  engine
  client
  desktop-client/.workspace
  backend/.workspace
  fengine/.workspace
  fll/.workspace
)

for path_name in "${forbidden[@]}"; do
  if [[ -e "$path_name" ]]; then
    echo "error: migrated source path still exists: $path_name" >&2
    exit 1
  fi
done

git_dir_count="$(
  find . \
    \( -path ./build -o -path ./.workspace \) -prune -o \
    -type d -name .git -prune -print | wc -l | tr -d ' '
)"
if [[ "$git_dir_count" != "1" ]]; then
  echo "error: expected exactly one .git directory, found $git_dir_count" >&2
  exit 1
fi

for trackable_path in \
  desktop-client/lib/main.dart \
  desktop-client/pubspec.lock \
  fll/Cargo.lock \
  backend/admin-web/package-lock.json \
  dependencies/ffmpeg/README.md; do
  if git check-ignore -q --no-index "$trackable_path"; then
    echo "error: trackable path is ignored: $trackable_path" >&2
    exit 1
  fi
done

echo "repository structure verified"
