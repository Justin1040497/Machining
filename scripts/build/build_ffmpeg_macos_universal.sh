#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM64_DIR="${ARM64_DIR:-${ROOT}/third_party/ffmpeg/macos-arm64}"
X64_DIR="${X64_DIR:-${ROOT}/third_party/ffmpeg/macos-x64}"
OUT_DIR="${OUT_DIR:-${ROOT}/third_party/ffmpeg/macos-universal}"
VERIFY_SCRIPT="${ROOT}/scripts/release/verify_macos_universal.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal FFmpeg merging must run on macOS" >&2
  exit 1
fi

for command_name in chmod grep lipo mkdir otool; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

require_single_arch_binary() {
  local path="$1"
  local expected_arch="$2"

  if [[ ! -x "$path" ]]; then
    echo "error: required executable not found: $path" >&2
    exit 1
  fi

  local actual_arches
  actual_arches="$(lipo -archs "$path")"
  if [[ "$actual_arches" != "$expected_arch" ]]; then
    echo "error: expected $expected_arch binary at $path, got $actual_arches" >&2
    exit 1
  fi
}

for binary_name in ffmpeg ffprobe; do
  require_single_arch_binary "$ARM64_DIR/$binary_name" arm64
  require_single_arch_binary "$X64_DIR/$binary_name" x86_64
done

mkdir -p "$OUT_DIR"
for binary_name in ffmpeg ffprobe; do
  lipo -create \
    "$ARM64_DIR/$binary_name" \
    "$X64_DIR/$binary_name" \
    -output "$OUT_DIR/$binary_name"
  chmod 755 "$OUT_DIR/$binary_name"
done

"$VERIFY_SCRIPT" "$OUT_DIR/ffmpeg" "$OUT_DIR/ffprobe"

for binary_name in ffmpeg ffprobe; do
  if otool -L "$OUT_DIR/$binary_name" | grep -E '/opt/homebrew|/usr/local/Cellar' >/dev/null; then
    echo "error: Universal $binary_name depends on Homebrew libraries" >&2
    otool -L "$OUT_DIR/$binary_name" >&2
    exit 1
  fi
done

encoder_output="$("$OUT_DIR/ffmpeg" -hide_banner -encoders 2>/dev/null)"
decoder_output="$("$OUT_DIR/ffmpeg" -hide_banner -decoders 2>/dev/null)"
demuxer_output="$("$OUT_DIR/ffmpeg" -hide_banner -demuxers 2>/dev/null)"
filter_output="$("$OUT_DIR/ffmpeg" -hide_banner -filters 2>/dev/null)"
for encoder_name in libx264 libmp3lame libwebp libopus; do
  if ! grep "$encoder_name" <<<"$encoder_output" >/dev/null; then
    echo "error: Universal FFmpeg is missing encoder: $encoder_name" >&2
    exit 1
  fi
done
for decoder_name in opus vorbis; do
  if ! grep "$decoder_name" <<<"$decoder_output" >/dev/null; then
    echo "error: Universal FFmpeg is missing decoder: $decoder_name" >&2
    exit 1
  fi
done
if ! grep "ogg" <<<"$demuxer_output" >/dev/null; then
  echo "error: Universal FFmpeg is missing demuxer: ogg" >&2
  exit 1
fi
for filter_name in zscale tonemap; do
  if ! grep "$filter_name" <<<"$filter_output" >/dev/null; then
    echo "error: Universal FFmpeg is missing filter: $filter_name" >&2
    exit 1
  fi
done

cat > "$OUT_DIR/ffmpeg-build-info.txt" <<EOF
Target: macOS Universal 2
Architectures: x86_64 arm64
arm64 source: ${ARM64_DIR}
x86_64 source: ${X64_DIR}
Merged by: scripts/build/build_ffmpeg_macos_universal.sh
EOF

echo
echo "Universal FFmpeg runtime is ready:"
echo "$OUT_DIR"
