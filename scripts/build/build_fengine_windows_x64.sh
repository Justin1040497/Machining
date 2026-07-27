#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUST_TARGET="x86_64-pc-windows-gnu"
SDK_DIR="${ROOT}/build/dependencies/ffmpeg/windows-x64"
OUT_DIR="${ROOT}/build/dependencies/fengine/windows-x64"
ENGINE_PATH="${ROOT}/fengine/target/${RUST_TARGET}/release/framelean-engine.exe"

case "$(uname -s)" in
  MINGW64_NT* | MSYS_NT* | MINGW32_NT*) ;;
  *)
    echo "error: this script must be run under MSYS2/MinGW-w64" >&2
    exit 1
    ;;
esac

for command_name in cargo grep install objdump rustup; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

if [[ ! -d "$SDK_DIR/include" || ! -d "$SDK_DIR/lib/pkgconfig" ]]; then
  echo "error: bundled static libav SDK is missing: $SDK_DIR" >&2
  echo "build it first with scripts/build/build_ffmpeg_windows_x64.sh" >&2
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
install -m 755 "$ENGINE_PATH" "$OUT_DIR/framelean-engine.exe"

dependency_output="$(objdump -p "$OUT_DIR/framelean-engine.exe")"
if grep -Eiq 'DLL Name:.*(avcodec|avdevice|avfilter|avformat|avutil|swresample|swscale|libstdc\+\+|libgcc)' <<<"$dependency_output"; then
  echo "error: FEngine has an unexpected dynamic media or GNU runtime dependency" >&2
  grep -Ei 'DLL Name:' <<<"$dependency_output" >&2
  exit 1
fi

"$OUT_DIR/framelean-engine.exe" --version
echo "Built Windows x64 FEngine with bundled static libav:"
echo "$OUT_DIR/framelean-engine.exe"
