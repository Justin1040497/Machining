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
BUILD_DIR="${ROOT}/build/qmc-decrypt-macos-${ARCH_LABEL}"
OUT_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-${ARCH_LABEL}"
REPO_URL="https://github.com/bczhc/qmc-decrypt.git"
REPO_COMMIT="12d758a6a08635b4ab85b6dca05025fdbcc26520"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script only builds the macOS QMC adapter" >&2
  exit 1
fi

if [[ "$(uname -m)" != "$ARCH" ]]; then
  echo "error: $ARCH adapter must be built on a native $ARCH macOS host" >&2
  exit 1
fi

for command_name in cargo git install lipo; do
  require_command "$command_name"
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

git clone --recursive "$REPO_URL" "$BUILD_DIR/qmc-decrypt"
cd "$BUILD_DIR/qmc-decrypt"
git checkout "$REPO_COMMIT"
git submodule update --init --recursive

cargo build --release --locked --target "$RUST_TARGET"

install -m 755 \
  "target/${RUST_TARGET}/release/qmc-decrypt" \
  "$OUT_DIR/qmc-decrypt"
install -m 644 "LICENSE-MIT" "$OUT_DIR/LICENSE-MIT"
install -m 644 "LICENSE-APACHE" "$OUT_DIR/LICENSE-APACHE"
install -m 644 "README.md" "$OUT_DIR/README-upstream.md"

built_arches="$(lipo -archs "$OUT_DIR/qmc-decrypt")"
if [[ "$built_arches" != "$ARCH" ]]; then
  echo "error: expected qmc-decrypt architecture $ARCH, got $built_arches" >&2
  exit 1
fi

cat > "$OUT_DIR/qmc-decrypt-build-info.txt" <<EOF
qmc-decrypt source: $REPO_URL
qmc-decrypt commit: $REPO_COMMIT
Rust target: $RUST_TARGET
Target: macOS $ARCH
Built by: scripts/build/build_qmc_decrypt_macos_arch.sh
EOF

"$OUT_DIR/qmc-decrypt" --help >/dev/null

echo
echo "macOS $ARCH QMC adapter is ready:"
echo "$OUT_DIR/qmc-decrypt"
