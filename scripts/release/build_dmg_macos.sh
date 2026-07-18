#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLIENT_ROOT="${ROOT}/desktop-client"
RELEASE_DIR="${CLIENT_ROOT}/build/macos/Build/Products/Release"
APP_PATH="${RELEASE_DIR}/FrameLean.app"
DMG_SOURCE_PATH="${RELEASE_DIR}/FrameLean.dmg"
FFMPEG_DIR="${ROOT}/build/dependencies/ffmpeg/macos-universal"
FFMPEG_ARM64_DIR="${ROOT}/build/dependencies/ffmpeg/macos-arm64"
FFMPEG_X64_DIR="${ROOT}/build/dependencies/ffmpeg/macos-x64"
QMC_ADAPTER_DIR="${ROOT}/build/dependencies/qmc/macos-universal"
QMC_ARM64_DIR="${ROOT}/build/dependencies/qmc/macos-arm64"
QMC_X64_DIR="${ROOT}/build/dependencies/qmc/macos-x64"
LEGAL_DIR="${ROOT}/legal"
PUBSPEC_PATH="${CLIENT_ROOT}/pubspec.yaml"
VERIFY_SCRIPT="${ROOT}/scripts/release/verify_macos_universal.sh"
MERGE_FFMPEG_SCRIPT="${ROOT}/scripts/build/build_ffmpeg_macos_universal.sh"
MERGE_QMC_SCRIPT="${ROOT}/scripts/build/build_qmc_decrypt_macos_universal.sh"
UPDATE_METADATA_JSON_PATH=""
REQUIRE_SPARKLE_SIGNATURE="${FRAMELEAN_REQUIRE_SPARKLE_SIGNATURE:-false}"
UPDATE_BASE_URL="${FRAMELEAN_UPDATE_BASE_URL:-}"
UPDATE_CHANNEL="${FRAMELEAN_UPDATE_CHANNEL:-stable}"
SPARKLE_FEED_URL="${FRAMELEAN_SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_KEY="${FRAMELEAN_SPARKLE_PUBLIC_ED_KEY:-}"
USE_SPARKLE_UPDATES="${FRAMELEAN_USE_SPARKLE_UPDATES:-false}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

binary_arches() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing"
    return
  fi
  lipo -archs "$path" 2>/dev/null || echo "unknown"
}

binary_has_exact_arch() {
  local path="$1"
  local expected_arch="$2"
  [[ -x "$path" && "$(binary_arches "$path")" == "$expected_arch" ]]
}

binary_is_universal2() {
  local path="$1"
  local architectures
  [[ -x "$path" ]] || return 1
  architectures="$(binary_arches "$path")"
  [[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
}

ffmpeg_universal_runtime_is_ready() {
  binary_is_universal2 "$FFMPEG_DIR/ffmpeg" &&
    binary_is_universal2 "$FFMPEG_DIR/ffprobe"
}

ffmpeg_slices_are_ready() {
  binary_has_exact_arch "$FFMPEG_ARM64_DIR/ffmpeg" arm64 &&
    binary_has_exact_arch "$FFMPEG_ARM64_DIR/ffprobe" arm64 &&
    binary_has_exact_arch "$FFMPEG_X64_DIR/ffmpeg" x86_64 &&
    binary_has_exact_arch "$FFMPEG_X64_DIR/ffprobe" x86_64
}

print_ffmpeg_runtime_status() {
  echo "Detected FFmpeg architectures:" >&2
  echo "  macos-universal/ffmpeg: $(binary_arches "$FFMPEG_DIR/ffmpeg")" >&2
  echo "  macos-universal/ffprobe: $(binary_arches "$FFMPEG_DIR/ffprobe")" >&2
  echo "  macos-arm64/ffmpeg: $(binary_arches "$FFMPEG_ARM64_DIR/ffmpeg")" >&2
  echo "  macos-arm64/ffprobe: $(binary_arches "$FFMPEG_ARM64_DIR/ffprobe")" >&2
  echo "  macos-x64/ffmpeg: $(binary_arches "$FFMPEG_X64_DIR/ffmpeg")" >&2
  echo "  macos-x64/ffprobe: $(binary_arches "$FFMPEG_X64_DIR/ffprobe")" >&2
}

fail_for_unprepared_ffmpeg_runtime() {
  echo "error: macOS Universal 2 FFmpeg runtime is not ready" >&2
  print_ffmpeg_runtime_status
  echo >&2
  echo "The macos-arm64 and macos-x64 directories are build inputs, not release packages." >&2
  echo "Do not copy arm64 files into macos-x64; the Intel slice must report x86_64." >&2
  echo >&2
  echo "Recommended: run the GitHub Actions workflow 'Build macOS Universal'." >&2
  echo "It builds both native slices and outputs one final FrameLean-v<version>.dmg." >&2
  echo >&2
  echo "For a local build, first provide valid native slices, then run:" >&2
  echo "  scripts/build/build_ffmpeg_macos_universal.sh" >&2
  exit 1
}

resolve_sparkle_sign_update() {
  if [[ -n "${SPARKLE_SIGN_UPDATE_PATH:-}" ]]; then
    if [[ -x "$SPARKLE_SIGN_UPDATE_PATH" ]]; then
      echo "$SPARKLE_SIGN_UPDATE_PATH"
      return 0
    fi
    echo "error: SPARKLE_SIGN_UPDATE_PATH is not executable: $SPARKLE_SIGN_UPDATE_PATH" >&2
    return 1
  fi

  local candidates=(
    "$CLIENT_ROOT/macos/Pods/Sparkle/bin/sign_update"
    "$CLIENT_ROOT/macos/Pods/Sparkle/Sparkle/bin/sign_update"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

write_sparkle_signature_metadata() {
  local dmg_path="$1"
  local sign_update_path
  if ! sign_update_path="$(resolve_sparkle_sign_update)"; then
    if [[ "$REQUIRE_SPARKLE_SIGNATURE" == "true" ]]; then
      echo "error: Sparkle sign_update was not found" >&2
      exit 1
    fi
    echo "warning: Sparkle sign_update was not found; skipping Sparkle signature metadata" >&2
    return 0
  fi

  local output
  output="$("$sign_update_path" "$dmg_path")"
  local signature
  local length
  signature="$(sed -nE 's/.*sparkle:edSignature="([^"]+)".*/\1/p' <<<"$output" | head -n 1)"
  length="$(sed -nE 's/.*length="([0-9]+)".*/\1/p' <<<"$output" | head -n 1)"
  if [[ -z "$signature" || -z "$length" ]]; then
    echo "error: could not parse Sparkle signature output:" >&2
    echo "$output" >&2
    exit 1
  fi

  local actual_length
  actual_length="$(stat -f '%z' "$dmg_path")"
  if [[ "$length" != "$actual_length" ]]; then
    echo "error: Sparkle length does not match the DMG length" >&2
    exit 1
  fi
  local sha256
  sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"

  UPDATE_METADATA_JSON_PATH="${dmg_path}.update.json"
  cat >"$UPDATE_METADATA_JSON_PATH" <<EOF
{
  "schemaVersion": 1,
  "version": "$APP_VERSION",
  "buildNumber": $APP_BUILD,
  "platform": "macos-universal2",
  "fileName": "$(basename "$dmg_path")",
  "size": $length,
  "sha256": "$sha256",
  "ed25519Signature": "$signature"
}
EOF
}

write_manual_update_metadata() {
  local dmg_path="$1"
  local length
  length="$(stat -f '%z' "$dmg_path")"
  local sha256
  sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"

  UPDATE_METADATA_JSON_PATH="${dmg_path}.update.json"
  cat >"$UPDATE_METADATA_JSON_PATH" <<EOF
{
  "schemaVersion": 1,
  "version": "$APP_VERSION",
  "buildNumber": $APP_BUILD,
  "platform": "macos-universal2",
  "fileName": "$(basename "$dmg_path")",
  "size": $length,
  "sha256": "$sha256"
}
EOF
}

inject_sparkle_settings() {
  local plist_path="$APP_PATH/Contents/Info.plist"
  local feed_url="$SPARKLE_FEED_URL"
  local public_key="$SPARKLE_PUBLIC_KEY"

  if [[ -n "$feed_url" ]]; then
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL $feed_url" "$plist_path"
  fi
  if [[ -n "$public_key" ]]; then
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $public_key" "$plist_path"
  fi

  if [[ "$REQUIRE_SPARKLE_SIGNATURE" == "true" ]]; then
    local compiled_feed_url
    local compiled_public_key
    compiled_feed_url="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$plist_path")"
    compiled_public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist_path")"
    if [[ -z "$compiled_feed_url" || "$compiled_feed_url" != https://* ]]; then
      echo "error: the built app must contain an HTTPS SUFeedURL" >&2
      exit 1
    fi
    if [[ -z "$compiled_public_key" ]]; then
      echo "error: the built app must contain SUPublicEDKey" >&2
      exit 1
    fi
  fi
}

assert_macos_cocoapods_project() {
  local missing_files=()
  local missing_ref_files=()

  for path in \
    "$CLIENT_ROOT/macos/Podfile" \
    "$CLIENT_ROOT/macos/Podfile.lock"; do
    if [[ ! -f "$path" ]]; then
      missing_files+=("${path#$ROOT/}")
    fi
  done

  if [[ "${#missing_files[@]}" -gt 0 ]]; then
    echo "error: macOS CocoaPods integration is incomplete:" >&2
    printf '  %s\n' "${missing_files[@]}" >&2
    echo "Run flutter pub get and pod install before building the Universal 2 DMG." >&2
    exit 1
  fi

  for path in \
    "$CLIENT_ROOT/macos/Flutter/Flutter-Debug.xcconfig" \
    "$CLIENT_ROOT/macos/Flutter/Flutter-Release.xcconfig" \
    "$CLIENT_ROOT/macos/Runner.xcodeproj/project.pbxproj" \
    "$CLIENT_ROOT/macos/Runner.xcworkspace/contents.xcworkspacedata"; do
    if [[ ! -f "$path" ]] || ! grep -E 'Pods-Runner|Pods_Runner|\[CP\]|Pods/Pods\.xcodeproj' "$path" >/dev/null; then
      missing_ref_files+=("${path#$ROOT/}")
    fi
  done

  if [[ "${#missing_ref_files[@]}" -gt 0 ]]; then
    echo "error: macOS project is missing CocoaPods references:" >&2
    printf '  %s\n' "${missing_ref_files[@]}" >&2
    echo "Keep the Runner workspace and Pods xcconfig references in sync before building the Universal 2 DMG." >&2
    exit 1
  fi
}

bundled_ffmpeg_has_required_capabilities() {
  local ffmpeg_path="$FFMPEG_DIR/ffmpeg"
  local encoder_output
  local decoder_output
  local demuxer_output
  local muxer_output
  local filter_output

  encoder_output="$("$ffmpeg_path" -hide_banner -encoders 2>/dev/null || true)"
  decoder_output="$("$ffmpeg_path" -hide_banner -decoders 2>/dev/null || true)"
  demuxer_output="$("$ffmpeg_path" -hide_banner -demuxers 2>/dev/null || true)"
  muxer_output="$("$ffmpeg_path" -hide_banner -muxers 2>/dev/null || true)"
  filter_output="$("$ffmpeg_path" -hide_banner -filters 2>/dev/null || true)"

  for encoder_name in libx264 libmp3lame libwebp libopus libvpx-vp9 libsvtav1 mpeg4 mjpeg prores_ks; do
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

  for muxer_name in mp4 mov matroska webm avi; do
    if ! grep "$muxer_name" <<<"$muxer_output" >/dev/null; then
      echo "Universal FFmpeg runtime is missing muxer: $muxer_name"
      return 1
    fi
  done

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
APP_BUILD="$(sed -nE 's/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)[[:space:]]*$/\1/p' "$PUBSPEC_PATH" | head -n 1)"
APP_BUILD="${APP_BUILD:-0}"

DMG_PATH="${RELEASE_DIR}/FrameLean-v${APP_VERSION}.dmg"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS DMG package" >&2
  exit 1
fi

if [[ -z "$UPDATE_BASE_URL" || "$UPDATE_BASE_URL" != https://* ]]; then
  echo "error: FRAMELEAN_UPDATE_BASE_URL must be an HTTPS URL" >&2
  exit 1
fi

if [[ "$REQUIRE_SPARKLE_SIGNATURE" == "true" ]]; then
  if [[ -z "$SPARKLE_FEED_URL" || "$SPARKLE_FEED_URL" != https://* ]]; then
    echo "error: FRAMELEAN_SPARKLE_FEED_URL must be an HTTPS URL when Sparkle signature metadata is required" >&2
    exit 1
  fi
  if [[ ! "$SPARKLE_PUBLIC_KEY" =~ ^[a-zA-Z0-9+/]{43}=$ ]]; then
    echo "error: FRAMELEAN_SPARKLE_PUBLIC_ED_KEY is required when Sparkle signature metadata is required" >&2
    exit 1
  fi
  if [[ "$#" -eq 0 || " $* " == *" --no-sign "* || " $* " == *" --no-notarization "* ]]; then
    echo "error: Sparkle signature metadata requires DMG signing and notarization" >&2
    exit 1
  fi
fi

for command_name in dart dmgbuild flutter hdiutil lipo python3 shasum; do
  require_command "$command_name"
done
if [[ "$REQUIRE_SPARKLE_SIGNATURE" == "true" ]]; then
  for command_name in codesign spctl xcrun; do
    require_command "$command_name"
  done
fi

if [[ ! -d "$LEGAL_DIR" ]]; then
  echo "error: legal materials directory not found: $LEGAL_DIR" >&2
  exit 1
fi

if ! ffmpeg_universal_runtime_is_ready; then
  if ffmpeg_slices_are_ready; then
    "$MERGE_FFMPEG_SCRIPT"
  else
    fail_for_unprepared_ffmpeg_runtime
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
cd "$CLIENT_ROOT"
rm -rf "${CLIENT_ROOT}/build/macos"
assert_macos_cocoapods_project
dart run "${ROOT}/tools/generate_build_info.dart"
flutter build macos \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-macos-info \
  --dart-define="FRAMELEAN_UPDATE_BASE_URL=$UPDATE_BASE_URL" \
  --dart-define="FRAMELEAN_UPDATE_CHANNEL=$UPDATE_CHANNEL" \
  --dart-define="FRAMELEAN_USE_SPARKLE_UPDATES=$USE_SPARKLE_UPDATES"
assert_macos_cocoapods_project

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Release app was not generated: $APP_PATH" >&2
  exit 1
fi

inject_sparkle_settings

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

dmg_args=("$@" "--no-build" "--settings" "$ROOT/scripts/release/dmg_settings.py")
if [[ "$#" -eq 0 ]]; then
  dmg_args=(--no-sign --no-notarization --no-build --settings "$ROOT/scripts/release/dmg_settings.py")
fi

# Generate custom DMG background image
BG_PATH="${CLIENT_ROOT}/build/macos/dmg_background.png"
echo "Generating DMG background..."
python3 "$ROOT/scripts/release/generate_dmg_background.py" "$BG_PATH" || {
  echo "warning: Failed to generate DMG background, falling back to builtin-arrow" >&2
}

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
if [[ "$REQUIRE_SPARKLE_SIGNATURE" == "true" ]]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type install --verbose=2 "$DMG_PATH"
  write_sparkle_signature_metadata "$DMG_PATH"
else
  write_manual_update_metadata "$DMG_PATH"
  echo "Manual DMG update metadata generated without Sparkle signature."
fi

echo
echo "Universal 2 DMG package is ready:"
echo "$DMG_PATH"
if [[ -n "$UPDATE_METADATA_JSON_PATH" ]]; then
  echo "Update metadata:"
  echo "$UPDATE_METADATA_JSON_PATH"
fi
