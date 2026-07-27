#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM64_DIR="${ARM64_DIR:-${ROOT}/build/dependencies/ffmpeg/macos-arm64}"
X64_DIR="${X64_DIR:-${ROOT}/build/dependencies/ffmpeg/macos-x64}"
OUT_DIR="${OUT_DIR:-${ROOT}/build/dependencies/ffmpeg/macos-universal}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal FFmpeg merging must run on macOS" >&2
  exit 1
fi

for command_name in cp find lipo mkdir sed sort; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

require_single_arch_library() {
  local path="$1"
  local expected_arch="$2"

  if [[ ! -f "$path" ]]; then
    echo "error: required static library not found: $path" >&2
    exit 1
  fi

  local actual_arches
  actual_arches="$(lipo -archs "$path")"
  if [[ "$actual_arches" != "$expected_arch" ]]; then
    echo "error: expected $expected_arch static library at $path, got $actual_arches" >&2
    if [[ "$expected_arch" == "x86_64" && "$actual_arches" == "arm64" ]]; then
      echo "Build the Intel SDK slice on an x86_64 macOS runner or use the GitHub Actions workflow 'Desktop Client'." >&2
    fi
    exit 1
  fi
}

for library_name in avcodec avdevice avfilter avformat avutil swresample swscale; do
  require_single_arch_library "$ARM64_DIR/lib/lib${library_name}.a" arm64
  require_single_arch_library "$X64_DIR/lib/lib${library_name}.a" x86_64
done

rm -rf "$OUT_DIR/include" "$OUT_DIR/lib"
mkdir -p "$OUT_DIR/include" "$OUT_DIR/lib/pkgconfig"
cp -R "$ARM64_DIR/include/." "$OUT_DIR/include/"

while IFS= read -r arm64_library; do
  library_name="${arm64_library##*/}"
  x64_library="$X64_DIR/lib/$library_name"
  if [[ ! -f "$x64_library" ]]; then
    echo "error: Intel SDK is missing static library: $library_name" >&2
    exit 1
  fi
  lipo -create "$arm64_library" "$x64_library" -output "$OUT_DIR/lib/$library_name"
done < <(find "$ARM64_DIR/lib" -maxdepth 1 -type f -name '*.a' -print | sort)

cp "$ARM64_DIR/lib/pkgconfig/"*.pc "$OUT_DIR/lib/pkgconfig/"
pkg_config_root='${pcfiledir}/../..'
while IFS= read -r pkg_config_file; do
  sed -i '' \
    -e "s|${ARM64_DIR}|${pkg_config_root}|g" \
    -e "s|${X64_DIR}|${pkg_config_root}|g" \
    -e "s|${OUT_DIR}|${pkg_config_root}|g" \
    "$pkg_config_file"
done < <(find "$OUT_DIR/lib/pkgconfig" -maxdepth 1 -type f -name '*.pc' -print)

cat > "$OUT_DIR/ffmpeg-build-info.txt" <<EOF
Target: macOS Universal 2
Architectures: x86_64 arm64
arm64 source: ${ARM64_DIR}
x86_64 source: ${X64_DIR}
Merged by: scripts/build/build_ffmpeg_macos_universal.sh
Distribution: static libav SDK; no ffmpeg or ffprobe executables
EOF

echo
echo "Universal static libav SDK is ready:"
echo "$OUT_DIR"
