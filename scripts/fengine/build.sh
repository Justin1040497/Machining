#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/fengine"
"$ROOT/scripts/build/with_bundled_ffmpeg.sh" cargo check --all-targets --locked
"$ROOT/scripts/build/with_bundled_ffmpeg.sh" cargo test --locked
