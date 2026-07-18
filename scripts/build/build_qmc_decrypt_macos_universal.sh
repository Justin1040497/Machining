#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM64_DIR="${ARM64_DIR:-${ROOT}/build/dependencies/qmc/macos-arm64}"
X64_DIR="${X64_DIR:-${ROOT}/build/dependencies/qmc/macos-x64}"
OUT_DIR="${OUT_DIR:-${ROOT}/build/dependencies/qmc/macos-universal}"
VERIFY_SCRIPT="${ROOT}/scripts/release/verify_macos_universal.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Universal QMC adapter merging must run on macOS" >&2
  exit 1
fi

for command_name in chmod find install lipo mkdir; do
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

ARM64_SLICE_DIR="$(resolve_slice_dir "$ARM64_DIR" qmc-decrypt)"
X64_SLICE_DIR="$(resolve_slice_dir "$X64_DIR" qmc-decrypt)"

require_single_arch_binary "$ARM64_SLICE_DIR/qmc-decrypt" arm64
require_single_arch_binary "$X64_SLICE_DIR/qmc-decrypt" x86_64

mkdir -p "$OUT_DIR"
lipo -create \
  "$ARM64_SLICE_DIR/qmc-decrypt" \
  "$X64_SLICE_DIR/qmc-decrypt" \
  -output "$OUT_DIR/qmc-decrypt"
chmod 755 "$OUT_DIR/qmc-decrypt"

for file_name in LICENSE-MIT LICENSE-APACHE README-upstream.md; do
  if [[ -f "$ARM64_SLICE_DIR/$file_name" ]]; then
    install -m 644 "$ARM64_SLICE_DIR/$file_name" "$OUT_DIR/$file_name"
  fi
done

"$VERIFY_SCRIPT" "$OUT_DIR/qmc-decrypt"
"$OUT_DIR/qmc-decrypt" --help >/dev/null

cat > "$OUT_DIR/qmc-decrypt-build-info.txt" <<EOF
Target: macOS Universal 2
Architectures: x86_64 arm64
arm64 source: ${ARM64_SLICE_DIR}
x86_64 source: ${X64_SLICE_DIR}
Merged by: scripts/build/build_qmc_decrypt_macos_universal.sh
EOF

echo
echo "Universal QMC adapter is ready:"
echo "$OUT_DIR/qmc-decrypt"
