#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build/ffmpeg-macos-arm64"
SRC_DIR="${BUILD_DIR}/src"
PREFIX="${BUILD_DIR}/dist"
OUT_DIR="${ROOT}/third_party/ffmpeg/macos-arm64"
FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.1}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS arm64 FFmpeg runtime" >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "error: this script is intended for Apple Silicon arm64 hosts" >&2
  exit 1
fi

require_command clang
require_command curl
require_command git
require_command make
require_command nasm
require_command pkg-config
require_command tar

mkdir -p "$SRC_DIR" "$PREFIX" "$OUT_DIR"

cd "$SRC_DIR"
if [[ ! -d x264 ]]; then
  git clone https://code.videolan.org/videolan/x264.git
fi

cd "$SRC_DIR/x264"
git fetch --tags --quiet || echo "warning: x264 fetch failed; using the local checkout"

make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --disable-cli \
  --disable-opencl

make -j"$JOBS"
make install

cd "$SRC_DIR"
if [[ ! -f "ffmpeg-${FFMPEG_VERSION}.tar.xz" ]]; then
  curl -L "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
    -o "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fi

rm -rf "ffmpeg-${FFMPEG_VERSION}"
tar -xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"

cd "$SRC_DIR/ffmpeg-${FFMPEG_VERSION}"
make distclean >/dev/null 2>&1 || true

PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig" \
PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig" \
./configure \
  --prefix="$PREFIX" \
  --arch=arm64 \
  --target-os=darwin \
  --cc=clang \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --disable-shared \
  --enable-static \
  --disable-sdl2 \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib"

make -j"$JOBS"
make install

install -m 755 "$PREFIX/bin/ffmpeg" "$OUT_DIR/ffmpeg"
install -m 755 "$PREFIX/bin/ffprobe" "$OUT_DIR/ffprobe"

strip "$OUT_DIR/ffmpeg" >/dev/null 2>&1 || true
strip "$OUT_DIR/ffprobe" >/dev/null 2>&1 || true

cat > "$OUT_DIR/ffmpeg-build-info.txt" <<EOF
FFmpeg version: ${FFMPEG_VERSION}
x264 source: https://code.videolan.org/videolan/x264.git
FFmpeg source: https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
Target: macOS arm64
Configure flags:
  --enable-gpl
  --enable-version3
  --enable-libx264
  --enable-videotoolbox
  --enable-audiotoolbox
  --disable-shared
  --enable-static
  --disable-sdl2
  --disable-ffplay
  --disable-doc
  --disable-debug
  --pkg-config-flags=--static
Nonfree enabled: no
EOF

echo "Built FFmpeg runtime:"
"$OUT_DIR/ffmpeg" -version | head -3
"$OUT_DIR/ffprobe" -version | head -3

echo
echo "Checking for Homebrew dynamic library dependencies:"
if otool -L "$OUT_DIR/ffmpeg" | grep -E '/opt/homebrew|/usr/local/Cellar' >/dev/null; then
  echo "error: ffmpeg still depends on Homebrew libraries" >&2
  otool -L "$OUT_DIR/ffmpeg" >&2
  exit 1
fi

if otool -L "$OUT_DIR/ffprobe" | grep -E '/opt/homebrew|/usr/local/Cellar' >/dev/null; then
  echo "error: ffprobe still depends on Homebrew libraries" >&2
  otool -L "$OUT_DIR/ffprobe" >&2
  exit 1
fi

echo "OK: no Homebrew dynamic library dependencies detected"

echo
echo "Checking libx264 encoder:"
if "$OUT_DIR/ffmpeg" -hide_banner -encoders | grep 'libx264' >/dev/null; then
  echo "OK: libx264 encoder is available"
else
  echo "error: libx264 encoder was not found" >&2
  exit 1
fi
