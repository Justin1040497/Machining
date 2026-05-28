#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${ROOT}/build/macos/Build/Products/Release"
APP_PATH="${RELEASE_DIR}/FrameLean.app"
DMG_SOURCE_PATH="${RELEASE_DIR}/FrameLean.dmg"
FFMPEG_DIR="${ROOT}/third_party/ffmpeg/macos-arm64"
LEGAL_DIR="${ROOT}/legal"
PUBSPEC_PATH="${ROOT}/pubspec.yaml"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

APP_VERSION="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)(\+[^[:space:]]+)?[[:space:]]*$/\1/p' "$PUBSPEC_PATH" | head -n 1)"
if [[ -z "$APP_VERSION" ]]; then
  echo "error: could not read semantic version from $PUBSPEC_PATH" >&2
  exit 1
fi

DMG_PATH="${RELEASE_DIR}/FrameLean-v${APP_VERSION}.dmg"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS DMG package" >&2
  exit 1
fi

require_command dart
require_command flutter
require_command dmgbuild
require_command hdiutil

if [[ ! -d "$LEGAL_DIR" ]]; then
  echo "error: legal materials directory not found: $LEGAL_DIR" >&2
  exit 1
fi

if [[ ! -x "$FFMPEG_DIR/ffmpeg" || ! -x "$FFMPEG_DIR/ffprobe" ]]; then
  echo "Bundled FFmpeg runtime not found. Building macOS arm64 runtime..."
  "${ROOT}/scripts/build_ffmpeg_macos_arm64.sh"
fi

if [[ "$#" -eq 0 ]]; then
  set -- --no-sign --no-notarization
fi

echo "Building DMG with: dart run dmg $*"
cd "$ROOT"
rm -f "$DMG_SOURCE_PATH" "$DMG_PATH"
dart run dmg "$@"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Release app was not generated: $APP_PATH" >&2
  exit 1
fi

if [[ -f "$DMG_SOURCE_PATH" ]]; then
  echo "Renaming DMG to: $DMG_PATH"
  mv -f "$DMG_SOURCE_PATH" "$DMG_PATH"
elif [[ ! -f "$DMG_PATH" ]]; then
  echo "error: DMG was not generated: $DMG_SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -x "$APP_PATH/Contents/Resources/ffmpeg/ffmpeg" ]]; then
  echo "error: bundled ffmpeg is missing from the app package" >&2
  exit 1
fi

if [[ ! -x "$APP_PATH/Contents/Resources/ffmpeg/ffprobe" ]]; then
  echo "error: bundled ffprobe is missing from the app package" >&2
  exit 1
fi

if [[ ! -f "$APP_PATH/Contents/Resources/legal/COPYING" ]]; then
  echo "error: legal materials are missing from the app package" >&2
  exit 1
fi

hdiutil verify "$DMG_PATH"

echo
echo "DMG package is ready:"
echo "$DMG_PATH"
