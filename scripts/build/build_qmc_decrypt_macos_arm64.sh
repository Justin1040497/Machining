#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT}/build/qmc-decrypt-macos-arm64"
OUT_DIR="${ROOT}/third_party/audio_adapters/qmc/macos-arm64"
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

require_command git
require_command cargo

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

git clone --recursive "$REPO_URL" "$BUILD_DIR/qmc-decrypt"
cd "$BUILD_DIR/qmc-decrypt"
git checkout "$REPO_COMMIT"
git submodule update --init --recursive

cargo build --release --locked

install -m 755 "target/release/qmc-decrypt" "$OUT_DIR/qmc-decrypt"
install -m 644 "LICENSE-MIT" "$OUT_DIR/LICENSE-MIT"
install -m 644 "LICENSE-APACHE" "$OUT_DIR/LICENSE-APACHE"
install -m 644 "README.md" "$OUT_DIR/README-upstream.md"

cat > "$OUT_DIR/qmc-decrypt-build-info.txt" <<EOF
qmc-decrypt source: $REPO_URL
qmc-decrypt commit: $REPO_COMMIT
Built by: scripts/build/build_qmc_decrypt_macos_arm64.sh
EOF

"$OUT_DIR/qmc-decrypt" --version

echo
echo "QMC adapter is ready:"
echo "$OUT_DIR/qmc-decrypt"
