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

for command_name in chmod find grep lipo mkdir otool; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

slice_dir_has_binaries() {
  local dir="$1"
  shift

  for binary_name in "$@"; do
    if [[ ! -f "$dir/$binary_name" ]]; then
      return 1
    fi
  done

  return 0
}

resolve_slice_dir() {
  local root_dir="$1"
  shift
  local first_binary_name="$1"

  if slice_dir_has_binaries "$root_dir" "$@"; then
    echo "$root_dir"
    return
  fi

  if [[ ! -d "$root_dir" ]]; then
    echo "$root_dir"
    return
  fi

  local candidate
  while IFS= read -r candidate; do
    local candidate_dir="${candidate%/*}"
    if slice_dir_has_binaries "$candidate_dir" "$@"; then
      echo "$candidate_dir"
      return
    fi
  done < <(find "$root_dir" -type f -name "$first_binary_name" -print)

  echo "$root_dir"
}

require_single_arch_binary() {
  local path="$1"
  local expected_arch="$2"

  if [[ ! -f "$path" ]]; then
    echo "error: required executable not found: $path" >&2
    exit 1
  fi

  if [[ ! -x "$path" ]]; then
    chmod 755 "$path"
  fi

  if [[ ! -x "$path" ]]; then
    echo "error: required executable is not executable: $path" >&2
    exit 1
  fi

  local actual_arches
  actual_arches="$(lipo -archs "$path")"
  if [[ "$actual_arches" != "$expected_arch" ]]; then
    echo "error: expected $expected_arch binary at $path, got $actual_arches" >&2
    exit 1
  fi
}

ARM64_SLICE_DIR="$(resolve_slice_dir "$ARM64_DIR" ffmpeg ffprobe)"
X64_SLICE_DIR="$(resolve_slice_dir "$X64_DIR" ffmpeg ffprobe)"

for binary_name in ffmpeg ffprobe; do
  require_single_arch_binary "$ARM64_SLICE_DIR/$binary_name" arm64
  require_single_arch_binary "$X64_SLICE_DIR/$binary_name" x86_64
done

mkdir -p "$OUT_DIR"
for binary_name in ffmpeg ffprobe; do
  lipo -create \
    "$ARM64_SLICE_DIR/$binary_name" \
    "$X64_SLICE_DIR/$binary_name" \
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
muxer_output="$("$OUT_DIR/ffmpeg" -hide_banner -muxers 2>/dev/null)"
filter_output="$("$OUT_DIR/ffmpeg" -hide_banner -filters 2>/dev/null)"
for encoder_name in libx264 libmp3lame libwebp libopus libvpx-vp9 libsvtav1 mpeg4 mjpeg prores_ks; do
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
for muxer_name in mp4 mov matroska webm avi; do
  if ! grep "$muxer_name" <<<"$muxer_output" >/dev/null; then
    echo "error: Universal FFmpeg is missing muxer: $muxer_name" >&2
    exit 1
  fi
done
for filter_name in zscale tonemap; do
  if ! grep "$filter_name" <<<"$filter_output" >/dev/null; then
    echo "error: Universal FFmpeg is missing filter: $filter_name" >&2
    exit 1
  fi
done

cat > "$OUT_DIR/ffmpeg-build-info.txt" <<EOF
Target: macOS Universal 2
Architectures: x86_64 arm64
arm64 source: ${ARM64_SLICE_DIR}
x86_64 source: ${X64_SLICE_DIR}
Merged by: scripts/build/build_ffmpeg_macos_universal.sh
EOF

echo
echo "Universal FFmpeg runtime is ready:"
echo "$OUT_DIR"
