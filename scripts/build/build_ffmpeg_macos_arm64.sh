#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT}/build/ffmpeg-macos-arm64"
SRC_DIR="${BUILD_DIR}/src"
PREFIX="${BUILD_DIR}/dist"
OUT_DIR="${ROOT}/third_party/ffmpeg/macos-arm64"
FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.1}"
LAME_VERSION="${LAME_VERSION:-3.100}"
LIBWEBP_VERSION="${LIBWEBP_VERSION:-1.5.0}"
OPUS_VERSION="${OPUS_VERSION:-1.5.2}"
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
if [[ ! -f "lame-${LAME_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" \
    -o "lame-${LAME_VERSION}.tar.gz"
fi

rm -rf "lame-${LAME_VERSION}"
tar -xf "lame-${LAME_VERSION}.tar.gz"

cd "$SRC_DIR/lame-${LAME_VERSION}"
make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-frontend

make -j"$JOBS"
make install

cd "$SRC_DIR"
if [[ ! -f "libwebp-${LIBWEBP_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VERSION}.tar.gz" \
    -o "libwebp-${LIBWEBP_VERSION}.tar.gz"
fi

rm -rf "libwebp-${LIBWEBP_VERSION}"
tar -xf "libwebp-${LIBWEBP_VERSION}.tar.gz"

cd "$SRC_DIR/libwebp-${LIBWEBP_VERSION}"
make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-gl \
  --disable-sdl \
  --disable-png \
  --disable-jpeg \
  --disable-tiff \
  --disable-gif \
  --disable-wic

make -j"$JOBS"
make install

cd "$SRC_DIR"
if [[ ! -f "opus-${OPUS_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz" \
    -o "opus-${OPUS_VERSION}.tar.gz"
fi

rm -rf "opus-${OPUS_VERSION}"
tar -xf "opus-${OPUS_VERSION}.tar.gz"

cd "$SRC_DIR/opus-${OPUS_VERSION}"
make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-extra-programs \
  --disable-doc

make -j"$JOBS"
make install

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
  --enable-libmp3lame \
  --enable-libwebp \
  --enable-libopus \
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
LAME version: ${LAME_VERSION}
LAME source: https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz
libwebp version: ${LIBWEBP_VERSION}
libwebp source: https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VERSION}.tar.gz
Opus version: ${OPUS_VERSION}
Opus source: https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz
FFmpeg source: https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
Target: macOS arm64
Configure flags:
  --enable-gpl
  --enable-version3
  --enable-libx264
  --enable-libmp3lame
  --enable-libwebp
  --enable-libopus
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
require_encoder() {
  local encoder_name="$1"
  if "$OUT_DIR/ffmpeg" -hide_banner -encoders | grep "$encoder_name" >/dev/null; then
    echo "OK: $encoder_name encoder is available"
  else
    echo "error: $encoder_name encoder was not found" >&2
    exit 1
  fi
}

echo "Checking required encoders:"
require_encoder libx264
require_encoder libmp3lame
require_encoder libwebp
require_encoder libopus
