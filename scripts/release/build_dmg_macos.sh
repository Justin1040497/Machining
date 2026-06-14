#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_DIR="${ROOT}/build/macos/Build/Products/Release"
APP_PATH="${RELEASE_DIR}/FrameLean.app"
DMG_SOURCE_PATH="${RELEASE_DIR}/FrameLean.dmg"
FFMPEG_DIR="${ROOT}/third_party/ffmpeg/macos-universal"
FFMPEG_ARM64_DIR="${ROOT}/third_party/ffmpeg/macos-arm64"
FFMPEG_X64_DIR="${ROOT}/third_party/ffmpeg/macos-x64"
QMC_ADAPTER_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-universal"
QMC_ARM64_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-arm64"
QMC_X64_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-x64"
LEGAL_DIR="${ROOT}/legal"
PUBSPEC_PATH="${ROOT}/pubspec.yaml"
VERIFY_SCRIPT="${ROOT}/scripts/release/verify_macos_universal.sh"
MERGE_FFMPEG_SCRIPT="${ROOT}/scripts/build/build_ffmpeg_macos_universal.sh"
MERGE_QMC_SCRIPT="${ROOT}/scripts/build/build_qmc_decrypt_macos_universal.sh"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

assert_macos_swiftpm_project() {
  local stale_ref_files=()

  if [[ -e "$ROOT/macos/Podfile" || -e "$ROOT/macos/Podfile.lock" ]]; then
    echo "error: macOS CocoaPods integration is still present." >&2
    echo "Remove macos/Podfile and macos/Podfile.lock; the macOS project should use Flutter Swift Package Manager." >&2
    exit 1
  fi

  for path in \
    "$ROOT/macos/Flutter/Flutter-Debug.xcconfig" \
    "$ROOT/macos/Flutter/Flutter-Release.xcconfig" \
    "$ROOT/macos/Runner.xcodeproj/project.pbxproj" \
    "$ROOT/macos/Runner.xcworkspace/contents.xcworkspacedata"; do
    if [[ -f "$path" ]] && grep -E 'Pods-Runner|Pods_Runner|\[CP\]|Pods/Pods\.xcodeproj' "$path" >/dev/null; then
      stale_ref_files+=("${path#$ROOT/}")
    fi
  done

  if [[ "${#stale_ref_files[@]}" -gt 0 ]]; then
    echo "error: macOS project still contains CocoaPods references:" >&2
    printf '  %s\n' "${stale_ref_files[@]}" >&2
    echo "Remove CocoaPods references before building the Universal 2 DMG." >&2
    exit 1
  fi
}

bundled_ffmpeg_has_required_capabilities() {
  local ffmpeg_path="$FFMPEG_DIR/ffmpeg"
  local encoder_output
  local decoder_output
  local demuxer_output
  local filter_output

  encoder_output="$("$ffmpeg_path" -hide_banner -encoders 2>/dev/null || true)"
  decoder_output="$("$ffmpeg_path" -hide_banner -decoders 2>/dev/null || true)"
  demuxer_output="$("$ffmpeg_path" -hide_banner -demuxers 2>/dev/null || true)"
  filter_output="$("$ffmpeg_path" -hide_banner -filters 2>/dev/null || true)"

  for encoder_name in libx264 libmp3lame libwebp libopus; do
    if ! grep "$encoder_name" <<<"$encoder_output" >/dev/null; then
      echo "Universal FFmpeg runtime is missing encoder: $encoder_name"
      return 1
    fi
  done

  for decoder_name in opus vorbis; do
    if ! grep "$decoder_name" <<<"$decoder_output" >/dev/null; then
      echo "Universal FFmpeg runtime is missing decoder: $decoder_name"
      return 1
    fi
  done

  if ! grep "ogg" <<<"$demuxer_output" >/dev/null; then
    echo "Universal FFmpeg runtime is missing demuxer: ogg"
    return 1
  fi

  for filter_name in zscale tonemap; do
    if ! grep "$filter_name" <<<"$filter_output" >/dev/null; then
      echo "Universal FFmpeg runtime is missing filter: $filter_name"
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

for command_name in dart dmgbuild flutter hdiutil lipo; do
  require_command "$command_name"
done

if [[ ! -d "$LEGAL_DIR" ]]; then
  echo "error: legal materials directory not found: $LEGAL_DIR" >&2
  exit 1
fi

if [[ ! -x "$FFMPEG_DIR/ffmpeg" || ! -x "$FFMPEG_DIR/ffprobe" ]]; then
  if [[
    -x "$FFMPEG_ARM64_DIR/ffmpeg" &&
    -x "$FFMPEG_ARM64_DIR/ffprobe" &&
    -x "$FFMPEG_X64_DIR/ffmpeg" &&
    -x "$FFMPEG_X64_DIR/ffprobe"
  ]]; then
    "$MERGE_FFMPEG_SCRIPT"
  else
    echo "error: Universal FFmpeg runtime is not ready" >&2
    echo "Build both architecture slices, then run:" >&2
    echo "  scripts/build/build_ffmpeg_macos_universal.sh" >&2
    exit 1
  fi
fi

"$VERIFY_SCRIPT" "$FFMPEG_DIR/ffmpeg" "$FFMPEG_DIR/ffprobe"
if ! bundled_ffmpeg_has_required_capabilities; then
  echo "error: Universal FFmpeg runtime failed capability validation" >&2
  exit 1
fi

qmc_adapter_available=false
for adapter_name in framelean-qmc-adapter qmc-decrypt; do
  if [[ -x "$QMC_ADAPTER_DIR/$adapter_name" ]]; then
    "$VERIFY_SCRIPT" "$QMC_ADAPTER_DIR/$adapter_name"
    qmc_adapter_available=true
  fi
done

if [[ "$qmc_adapter_available" == false ]]; then
  if [[
    -x "$QMC_ARM64_DIR/qmc-decrypt" &&
    -x "$QMC_X64_DIR/qmc-decrypt"
  ]]; then
    "$MERGE_QMC_SCRIPT"
    "$VERIFY_SCRIPT" "$QMC_ADAPTER_DIR/qmc-decrypt"
  else
    echo "warning: Universal QMC adapter is unavailable; QMC inputs will not be bundled"
  fi
fi

echo "Building Universal 2 macOS app..."
cd "$ROOT"
rm -rf "${ROOT}/build/macos"
flutter config --enable-swift-package-manager
assert_macos_swiftpm_project
flutter build macos \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-macos-info
assert_macos_swiftpm_project

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Release app was not generated: $APP_PATH" >&2
  exit 1
fi

"$VERIFY_SCRIPT" "$APP_PATH"

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

for adapter_name in framelean-qmc-adapter qmc-decrypt; do
  if [[
    -x "$QMC_ADAPTER_DIR/$adapter_name" &&
    ! -x "$APP_PATH/Contents/Resources/audio_adapters/qmc/$adapter_name"
  ]]; then
    echo "error: Universal QMC adapter was not copied into the app package: $adapter_name" >&2
    exit 1
  fi
done

dmg_args=("$@" "--no-build")
if [[ "$#" -eq 0 ]]; then
  dmg_args=(--no-sign --no-notarization --no-build)
fi

echo "Building DMG with: dart run dmg ${dmg_args[*]}"
rm -f "$DMG_SOURCE_PATH" "$DMG_PATH"
dart run dmg "${dmg_args[@]}"

if [[ -f "$DMG_SOURCE_PATH" ]]; then
  echo "Renaming DMG to: $DMG_PATH"
  mv -f "$DMG_SOURCE_PATH" "$DMG_PATH"
elif [[ ! -f "$DMG_PATH" ]]; then
  echo "error: DMG was not generated: $DMG_SOURCE_PATH" >&2
  exit 1
fi

hdiutil verify "$DMG_PATH"

echo
echo "Universal 2 DMG package is ready:"
echo "$DMG_PATH"
