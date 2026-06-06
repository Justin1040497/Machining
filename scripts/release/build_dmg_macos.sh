#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_DIR="${ROOT}/build/macos/Build/Products/Release"
APP_PATH="${RELEASE_DIR}/FrameLean.app"
DMG_SOURCE_PATH="${RELEASE_DIR}/FrameLean.dmg"
FFMPEG_DIR="${ROOT}/third_party/ffmpeg/macos-arm64"
QMC_ADAPTER_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-arm64"
LEGAL_DIR="${ROOT}/legal"
PUBSPEC_PATH="${ROOT}/pubspec.yaml"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

bundled_ffmpeg_has_required_encoders() {
  local ffmpeg_path="$FFMPEG_DIR/ffmpeg"
  local encoder_output
  encoder_output="$("$ffmpeg_path" -hide_banner -encoders 2>/dev/null || true)"

  for encoder_name in libx264 libmp3lame libwebp libopus; do
    if ! grep "$encoder_name" <<<"$encoder_output" >/dev/null; then
      echo "Bundled FFmpeg runtime is missing encoder: $encoder_name"
      return 1
    fi
  done

  return 0
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
  "${ROOT}/scripts/build/build_ffmpeg_macos_arm64.sh"
elif ! bundled_ffmpeg_has_required_encoders; then
  echo "Bundled FFmpeg runtime is outdated. Rebuilding macOS arm64 runtime..."
  "${ROOT}/scripts/build/build_ffmpeg_macos_arm64.sh"
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

if [[ -x "$QMC_ADAPTER_DIR/framelean-qmc-adapter" || -x "$QMC_ADAPTER_DIR/qmc-decrypt" ]]; then
  if [[ ! -x "$APP_PATH/Contents/Resources/audio_adapters/qmc/framelean-qmc-adapter" && ! -x "$APP_PATH/Contents/Resources/audio_adapters/qmc/qmc-decrypt" ]]; then
    echo "error: QMC audio adapter source exists but was not copied into the app package" >&2
    exit 1
  fi
fi

hdiutil verify "$DMG_PATH"

echo
echo "DMG package is ready:"
echo "$DMG_PATH"
