#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT}/build/ffmpeg-windows-x64"
SRC_DIR="${BUILD_DIR}/src"
PREFIX="${BUILD_DIR}/dist"
OUT_DIR="${ROOT}/third_party/ffmpeg/windows-x64"
FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.1}"
LAME_VERSION="${LAME_VERSION:-3.100}"
LIBWEBP_VERSION="${LIBWEBP_VERSION:-1.5.0}"
OPUS_VERSION="${OPUS_VERSION:-1.5.2}"
ZIMG_VERSION="${ZIMG_VERSION:-3.0.6}"
LIBVPX_VERSION="${LIBVPX_VERSION:-1.15.2}"
SVT_AV1_VERSION="${SVT_AV1_VERSION:-2.3.0}"
JOBS="${JOBS:-$(nproc)}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

case "$(uname -s)" in
  MINGW64_NT* | MSYS_NT* | MINGW32_NT*)
    ;;
  *)
    echo "error: this script must be run under MSYS2/MinGW-w64" >&2
    exit 1
    ;;
esac

for command_name in gcc g++ cmake curl git install make nasm pkg-config strip tar; do
  require_command "$command_name"
done

rm -rf "$PREFIX"
mkdir -p "$SRC_DIR" "$PREFIX" "$OUT_DIR"

# ---- LAME ----
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

# ---- libvpx ----
cd "$SRC_DIR"
if [[ ! -f "libvpx-${LIBVPX_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://github.com/webmproject/libvpx/archive/refs/tags/v${LIBVPX_VERSION}.tar.gz" \
    -o "libvpx-${LIBVPX_VERSION}.tar.gz"
fi

rm -rf "libvpx-${LIBVPX_VERSION}"
tar -xf "libvpx-${LIBVPX_VERSION}.tar.gz"

cd "$SRC_DIR/libvpx-${LIBVPX_VERSION}"
make clean >/dev/null 2>&1 || true
./configure \
  --prefix="$PREFIX" \
  --target=x86_64-win64-gcc \
  --disable-shared \
  --enable-static \
  --disable-examples \
  --disable-tools \
  --disable-unit-tests \
  --disable-docs
make -j"$JOBS"
make install

# ---- SVT-AV1 ----
cd "$SRC_DIR"
if [[ ! -f "svt-av1-${SVT_AV1_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v${SVT_AV1_VERSION}/SVT-AV1-v${SVT_AV1_VERSION}.tar.gz" \
    -o "svt-av1-${SVT_AV1_VERSION}.tar.gz"
fi

rm -rf "SVT-AV1-v${SVT_AV1_VERSION}"
tar -xf "svt-av1-${SVT_AV1_VERSION}.tar.gz"

cmake \
  -S "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}" \
  -B "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}/Build/framelean" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  -DBUILD_TESTING=OFF
cmake --build "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}/Build/framelean" --parallel "$JOBS"
cmake --install "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}/Build/framelean"

# ---- libwebp ----
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

# ---- opus ----
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

# ---- zimg ----
cd "$SRC_DIR"
if [[ ! -f "zimg-release-${ZIMG_VERSION}.tar.gz" ]]; then
  curl -L \
    "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-${ZIMG_VERSION}.tar.gz" \
    -o "zimg-release-${ZIMG_VERSION}.tar.gz"
fi

rm -rf "zimg-release-${ZIMG_VERSION}"
tar -xf "zimg-release-${ZIMG_VERSION}.tar.gz"

cd "$SRC_DIR/zimg-release-${ZIMG_VERSION}"
make distclean >/dev/null 2>&1 || true
if [[ ! -x ./configure ]]; then
  for command_name in autoreconf aclocal automake libtoolize; do
    require_command "$command_name"
  done
  bash ./autogen.sh
fi
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static
make -j"$JOBS"
make install

# ---- x264 ----
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

# ---- FFmpeg ----
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
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-libmp3lame \
  --enable-libwebp \
  --enable-libopus \
  --enable-libzimg \
  --enable-libvpx \
  --enable-libsvtav1 \
  --enable-d3d11va \
  --enable-dxva2 \
  --disable-shared \
  --enable-static \
  --disable-sdl2 \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib -static-libgcc -static-libstdc++"

make -j"$JOBS"
make install

# ---- Install to output directory ----
install -m 755 "$PREFIX/bin/ffmpeg.exe" "$OUT_DIR/ffmpeg.exe"
install -m 755 "$PREFIX/bin/ffprobe.exe" "$OUT_DIR/ffprobe.exe"

strip "$OUT_DIR/ffmpeg.exe" >/dev/null 2>&1 || true
strip "$OUT_DIR/ffprobe.exe" >/dev/null 2>&1 || true

# ---- Architecture verification ----
for binary_name in ffmpeg.exe ffprobe.exe; do
  binary_path="$OUT_DIR/$binary_name"
  file_output="$(file "$binary_path")"
  if ! echo "$file_output" | grep -qE "PE32\+.*x86-64"; then
    echo "error: expected $binary_name to be PE32+ x86-64, got: $file_output" >&2
    exit 1
  fi
done

# ---- DLL dependency check ----
echo "Checking for unexpected DLL dependencies:"
for binary_name in ffmpeg.exe ffprobe.exe; do
  dlls="$(objdump -p "$OUT_DIR/$binary_name" | grep "DLL Name" || true)"
  if echo "$dlls" | grep -vE '(KERNEL32|ADVAPI32|SHELL32|ole32|OLEAUT32|USER32|WS2_32|GDI32|COMCTL32|SETUPAPI|bcrypt|PSAPI|WINMM|Secur32|IPHLPAPI|POWRPROF|CFGMGR32|D3D9|DXVA2|MF|MFPlat|MFReadWrite|SHLWAPI|AVICAP32|VERSION|UxTheme|d3d11|dxgi)' | grep -q "DLL Name"; then
    echo "error: $binary_name has unexpected DLL dependencies" >&2
    echo "$dlls" >&2
    exit 1
  fi
done

# ---- Build info ----
cat > "$OUT_DIR/ffmpeg-build-info.txt" <<EOF
FFmpeg version: ${FFMPEG_VERSION}
x264 source: https://code.videolan.org/videolan/x264.git
LAME version: ${LAME_VERSION}
LAME source: https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz
libwebp version: ${LIBWEBP_VERSION}
libwebp source: https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VERSION}.tar.gz
Opus version: ${OPUS_VERSION}
Opus source: https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz
zimg version: ${ZIMG_VERSION}
zimg source: https://github.com/sekrit-twc/zimg/archive/refs/tags/release-${ZIMG_VERSION}.tar.gz
libvpx version: ${LIBVPX_VERSION}
libvpx source: https://github.com/webmproject/libvpx/archive/refs/tags/v${LIBVPX_VERSION}.tar.gz
SVT-AV1 version: ${SVT_AV1_VERSION}
SVT-AV1 source: https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v${SVT_AV1_VERSION}/SVT-AV1-v${SVT_AV1_VERSION}.tar.gz
FFmpeg source: https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
Target: Windows x64
Nonfree enabled: no
Configure flags:
  --target-os=mingw32
  --arch=x86_64
  --enable-gpl
  --enable-version3
  --enable-libx264
  --enable-libmp3lame
  --enable-libwebp
  --enable-libopus
  --enable-libzimg
  --enable-libvpx
  --enable-libsvtav1
  --enable-d3d11va
  --enable-dxva2
  --disable-shared
  --enable-static
  --disable-sdl2
  --disable-ffplay
  --disable-doc
  --disable-debug
  --pkg-config-flags=--static
EOF

# ---- Capability validation ----
require_capability() {
  local output="$1"
  local capability="$2"
  local capability_type="$3"

  if grep "$capability" <<<"$output" >/dev/null; then
    echo "OK: $capability $capability_type is available"
    return
  fi

  echo "error: $capability $capability_type was not found" >&2
  exit 1
}

encoder_output="$("$OUT_DIR/ffmpeg.exe" -hide_banner -encoders 2>/dev/null)"
decoder_output="$("$OUT_DIR/ffmpeg.exe" -hide_banner -decoders 2>/dev/null)"
demuxer_output="$("$OUT_DIR/ffmpeg.exe" -hide_banner -demuxers 2>/dev/null)"
muxer_output="$("$OUT_DIR/ffmpeg.exe" -hide_banner -muxers 2>/dev/null)"
filter_output="$("$OUT_DIR/ffmpeg.exe" -hide_banner -filters 2>/dev/null)"

for encoder_name in libx264 libmp3lame libwebp libopus libvpx-vp9 libsvtav1 mpeg4 mjpeg prores_ks; do
  require_capability "$encoder_output" "$encoder_name" "encoder"
done
for decoder_name in opus vorbis; do
  require_capability "$decoder_output" "$decoder_name" "decoder"
done
require_capability "$demuxer_output" "ogg" "demuxer"
for muxer_name in mp4 mov matroska webm avi; do
  require_capability "$muxer_output" "$muxer_name" "muxer"
done
for filter_name in zscale tonemap; do
  require_capability "$filter_output" "$filter_name" "filter"
done

echo
echo "Built Windows x64 FFmpeg runtime:"
echo "$OUT_DIR"
