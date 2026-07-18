#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/fll"
cargo check --workspace --all-targets --locked
cargo test --workspace --locked
