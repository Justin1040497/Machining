#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM64_DIR="${ARM64_DIR:-${ROOT}/third_party/audio_adapters/qmc/macos-arm64}"
X64_DIR="${X64_DIR:-${ROOT}/third_party/audio_adapters/qmc/macos-x64}"
OUT_DIR="${OUT_DIR:-${ROOT}/third_party/audio_adapters/qmc/macos-universal}"
VERIFY_SCRIPT="${ROOT}/scripts/release/verify_macos_universal.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal QMC adapter merging must run on macOS" >&2
  exit 1
fi

for command_name in chmod install lipo mkdir; do
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

require_single_arch_binary "$ARM64_DIR/qmc-decrypt" arm64
require_single_arch_binary "$X64_DIR/qmc-decrypt" x86_64

mkdir -p "$OUT_DIR"
lipo -create \
  "$ARM64_DIR/qmc-decrypt" \
  "$X64_DIR/qmc-decrypt" \
  -output "$OUT_DIR/qmc-decrypt"
chmod 755 "$OUT_DIR/qmc-decrypt"

for file_name in LICENSE-MIT LICENSE-APACHE README-upstream.md; do
  if [[ -f "$ARM64_DIR/$file_name" ]]; then
    install -m 644 "$ARM64_DIR/$file_name" "$OUT_DIR/$file_name"
  fi
done

"$VERIFY_SCRIPT" "$OUT_DIR/qmc-decrypt"
"$OUT_DIR/qmc-decrypt" --help >/dev/null

cat > "$OUT_DIR/qmc-decrypt-build-info.txt" <<EOF
Target: macOS Universal 2
Architectures: x86_64 arm64
arm64 source: ${ARM64_DIR}
x86_64 source: ${X64_DIR}
Merged by: scripts/build/build_qmc_decrypt_macos_universal.sh
EOF

echo
echo "Universal QMC adapter is ready:"
echo "$OUT_DIR/qmc-decrypt"
