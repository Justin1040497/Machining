#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE_BIN="${ROOT}/fengine/target/debug/framelean-engine"

"${ROOT}/scripts/build/with_bundled_ffmpeg.sh" \
  cargo build \
  --manifest-path "${ROOT}/fengine/Cargo.toml" \
  --bin framelean-engine \
  --locked

(
  cd "${ROOT}/desktop-client"
  FRAMELEAN_FENGINE_BINARY="${ENGINE_BIN}" \
  FRAMELEAN_TEST_REMUX_PROGRESS_DELAY_MS=2 \
    flutter test test/local_fengine_gateway_real_e2e_test.dart
)
