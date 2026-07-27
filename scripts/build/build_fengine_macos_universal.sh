#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM64_ENGINE="${ARM64_ENGINE:-${ROOT}/build/dependencies/fengine/macos-arm64/framelean-engine}"
X64_ENGINE="${X64_ENGINE:-${ROOT}/build/dependencies/fengine/macos-x64/framelean-engine}"
OUT_DIR="${OUT_DIR:-${ROOT}/build/dependencies/fengine/macos-universal}"
OUT_ENGINE="${OUT_DIR}/framelean-engine"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal FEngine merging must run on macOS" >&2
  exit 1
fi

for command_name in grep install lipo mkdir otool; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "error: missing required command: $command_name" >&2
    exit 1
  fi
done

for engine_path in "$ARM64_ENGINE" "$X64_ENGINE"; do
  if [[ ! -x "$engine_path" ]]; then
    echo "error: FEngine slice is missing: $engine_path" >&2
    exit 1
  fi
done

if [[ "$(lipo -archs "$ARM64_ENGINE")" != "arm64" ]]; then
  echo "error: invalid arm64 FEngine slice: $ARM64_ENGINE" >&2
  exit 1
fi
if [[ "$(lipo -archs "$X64_ENGINE")" != "x86_64" ]]; then
  echo "error: invalid x86_64 FEngine slice: $X64_ENGINE" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
lipo -create "$ARM64_ENGINE" "$X64_ENGINE" -output "$OUT_ENGINE"
chmod 755 "$OUT_ENGINE"

architectures="$(lipo -archs "$OUT_ENGINE")"
if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
  echo "error: Universal FEngine is missing a required architecture: $architectures" >&2
  exit 1
fi

if otool -L "$OUT_ENGINE" | grep -Eiq 'libav(codec|device|filter|format|util)|libsw(resample|scale)'; then
  echo "error: Universal FEngine has a dynamic libav dependency" >&2
  otool -L "$OUT_ENGINE" >&2
  exit 1
fi

echo "Universal FEngine is ready:"
echo "$OUT_ENGINE"
