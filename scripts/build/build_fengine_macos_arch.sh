#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ARCH="${1:-}"
case "$ARCH" in
  arm64)
    ARCH_LABEL="arm64"
    RUST_TARGET="aarch64-apple-darwin"
    ;;
  x86_64)
    ARCH_LABEL="x64"
    RUST_TARGET="x86_64-apple-darwin"
    ;;
  *)
    echo "usage: $0 <arm64|x86_64>" >&2
    exit 64
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SDK_DIR="${ROOT}/build/dependencies/ffmpeg/macos-${ARCH_LABEL}"
OUT_DIR="${ROOT}/build/dependencies/fengine/macos-${ARCH_LABEL}"
ENGINE_PATH="${ROOT}/fengine/target/${RUST_TARGET}/release/framelean-engine"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS FEngine executable" >&2
  exit 1
fi

if [[ "$(uname -m)" != "$ARCH" ]]; then
  echo "error: $ARCH FEngine must be built on a native $ARCH macOS host" >&2
  exit 1
fi

for command_name in cargo grep install lipo otool rustup; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

if [[ ! -d "$SDK_DIR/include" || ! -d "$SDK_DIR/lib/pkgconfig" ]]; then
  echo "error: bundled static libav SDK is missing: $SDK_DIR" >&2
  echo "build it first with scripts/build/build_ffmpeg_macos_arch.sh $ARCH" >&2
  exit 1
fi

rustup target add "$RUST_TARGET"
FRAMELEAN_FFMPEG_SDK_DIR="$SDK_DIR" \
  "${ROOT}/scripts/build/with_bundled_ffmpeg.sh" \
  cargo build \
    --manifest-path "${ROOT}/fengine/Cargo.toml" \
    --release \
    --locked \
    --target "$RUST_TARGET"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
install -m 755 "$ENGINE_PATH" "$OUT_DIR/framelean-engine"

actual_arch="$(lipo -archs "$OUT_DIR/framelean-engine")"
if [[ "$actual_arch" != "$ARCH" ]]; then
  echo "error: expected FEngine architecture $ARCH, got $actual_arch" >&2
  exit 1
fi

if otool -L "$OUT_DIR/framelean-engine" | grep -Eiq 'libav(codec|device|filter|format|util)|libsw(resample|scale)'; then
  echo "error: FEngine has a dynamic libav dependency" >&2
  otool -L "$OUT_DIR/framelean-engine" >&2
  exit 1
fi

"$OUT_DIR/framelean-engine" --version
echo "Built macOS $ARCH FEngine with bundled static libav:"
echo "$OUT_DIR/framelean-engine"
