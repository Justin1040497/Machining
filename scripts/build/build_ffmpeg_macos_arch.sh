#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ARCH="${1:-}"
case "$ARCH" in
  arm64)
    ARCH_LABEL="arm64"
    ;;
  x86_64)
    ARCH_LABEL="x64"
    ;;
  *)
    echo "usage: $0 <arm64|x86_64>" >&2
    exit 64
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT}/build/ffmpeg-macos-${ARCH_LABEL}"
SRC_DIR="${BUILD_DIR}/src"
PREFIX="${BUILD_DIR}/dist"
OUT_DIR="${ROOT}/build/dependencies/ffmpeg/macos-${ARCH_LABEL}"
FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.1}"
LAME_VERSION="${LAME_VERSION:-3.100}"
LIBWEBP_VERSION="${LIBWEBP_VERSION:-1.5.0}"
OPUS_VERSION="${OPUS_VERSION:-1.5.2}"
ZIMG_VERSION="${ZIMG_VERSION:-3.0.6}"
LIBVPX_VERSION="${LIBVPX_VERSION:-1.15.2}"
SVT_AV1_VERSION="${SVT_AV1_VERSION:-2.3.0}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.15}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
ARCH_FLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS FFmpeg runtime" >&2
  exit 1
fi

if [[ "$(uname -m)" != "$ARCH" ]]; then
  echo "error: $ARCH runtime must be built on a native $ARCH macOS host" >&2
  exit 1
fi

for command_name in clang cmake cp curl find git install lipo make nasm pkg-config sed tar; do
  require_command "$command_name"
done

export MACOSX_DEPLOYMENT_TARGET
rm -rf "$PREFIX"
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
CFLAGS="$ARCH_FLAGS" CXXFLAGS="$ARCH_FLAGS" LDFLAGS="$ARCH_FLAGS" \
  ./configure \
    --prefix="$PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-frontend
make -j"$JOBS"
make install

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
    --disable-shared \
    --enable-static \
    --disable-examples \
    --disable-tools \
    --disable-unit-tests \
    --disable-docs \
    --extra-cflags="$ARCH_FLAGS"
make -j"$JOBS"
make install

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
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  -DBUILD_TESTING=OFF
cmake --build "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}/Build/framelean" --parallel "$JOBS"
cmake --install "$SRC_DIR/SVT-AV1-v${SVT_AV1_VERSION}/Build/framelean"

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
CFLAGS="$ARCH_FLAGS" CXXFLAGS="$ARCH_FLAGS" LDFLAGS="$ARCH_FLAGS" \
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
CFLAGS="$ARCH_FLAGS" CXXFLAGS="$ARCH_FLAGS" LDFLAGS="$ARCH_FLAGS" \
  ./configure \
    --prefix="$PREFIX" \
    --disable-shared \
    --enable-static \
    --disable-extra-programs \
    --disable-doc
make -j"$JOBS"
make install

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
  for command_name in autoreconf aclocal automake glibtoolize; do
    require_command "$command_name"
  done
  bash ./autogen.sh
fi
CFLAGS="$ARCH_FLAGS" CXXFLAGS="$ARCH_FLAGS" LDFLAGS="$ARCH_FLAGS" \
  CC=clang \
  CXX=clang++ \
STL_LIBS="-lc++" ./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static
make -j"$JOBS"
make install

cd "$SRC_DIR"
if [[ ! -d x264 ]]; then
  git clone https://code.videolan.org/videolan/x264.git
fi

cd "$SRC_DIR/x264"
git fetch --tags --quiet || echo "warning: x264 fetch failed; using the local checkout"
make distclean >/dev/null 2>&1 || true
CFLAGS="$ARCH_FLAGS" LDFLAGS="$ARCH_FLAGS" \
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
  --arch="$ARCH" \
  --target-os=darwin \
  --cc=clang \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-libmp3lame \
  --enable-libwebp \
  --enable-libopus \
  --enable-libzimg \
  --enable-libvpx \
  --enable-libsvtav1 \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --disable-shared \
  --enable-static \
  --disable-programs \
  --disable-sdl2 \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --pkg-config-flags="--static" \
  --extra-cflags="${ARCH_FLAGS} -I${PREFIX}/include" \
  --extra-ldflags="${ARCH_FLAGS} -L${PREFIX}/lib"

make -j"$JOBS"
make install

rm -rf "$OUT_DIR/include" "$OUT_DIR/lib"
mkdir -p "$OUT_DIR/include" "$OUT_DIR/lib/pkgconfig"
cp -R "$PREFIX/include/." "$OUT_DIR/include/"
find "$PREFIX/lib" -maxdepth 1 -type f -name '*.a' -exec cp {} "$OUT_DIR/lib/" \;
find "$PREFIX/lib/pkgconfig" -maxdepth 1 -type f -name '*.pc' -exec cp {} "$OUT_DIR/lib/pkgconfig/" \;

for library_name in avcodec avdevice avfilter avformat avutil swresample swscale; do
  library_path="$OUT_DIR/lib/lib${library_name}.a"
  if [[ ! -f "$library_path" ]]; then
    echo "error: missing required static library: $library_path" >&2
    exit 1
  fi
  built_arches="$(lipo -archs "$library_path")"
  if [[ "$built_arches" != "$ARCH" ]]; then
    echo "error: expected $library_name architecture $ARCH, got $built_arches" >&2
    exit 1
  fi
done

pkg_config_root='${pcfiledir}/../..'
while IFS= read -r pkg_config_file; do
  sed -i '' \
    -e "s|${PREFIX}|${pkg_config_root}|g" \
    -e "s|${OUT_DIR}|${pkg_config_root}|g" \
    "$pkg_config_file"
done < <(find "$OUT_DIR/lib/pkgconfig" -maxdepth 1 -type f -name '*.pc' -print)

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
Target: macOS ${ARCH}
Minimum macOS: ${MACOSX_DEPLOYMENT_TARGET}
Nonfree enabled: no
Distribution: static libav SDK; no ffmpeg or ffprobe executables
EOF

echo
echo "Built macOS $ARCH static libav SDK:"
echo "$OUT_DIR"
