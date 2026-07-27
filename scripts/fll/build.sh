#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/fll"
"$ROOT/scripts/build/with_bundled_ffmpeg.sh" cargo check --workspace --all-targets --locked
"$ROOT/scripts/build/with_bundled_ffmpeg.sh" cargo test --workspace --locked
