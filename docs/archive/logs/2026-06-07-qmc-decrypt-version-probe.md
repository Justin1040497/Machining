# QMC qmc-decrypt version probe

## Problem

Running `scripts/build/build_qmc_decrypt_macos_arm64.sh` could build the pinned upstream `qmc-decrypt` binary successfully, then fail at the final validation step:

```text
error: Found argument '--version' which wasn't expected, or isn't valid in this context
Usage: qmc-decrypt <input> <output> [ekey]
```

The same incorrect assumption existed in the Windows helper and in the direct `qmc-decrypt` runtime contract.

## Cause

FrameLean wrapper adapters support `--version`, but the pinned upstream `bczhc/qmc-decrypt` commit `12d758a6a08635b4ab85b6dca05025fdbcc26520` does not expose a version flag. Its side-effect-free probe is `--help`.

## Fix

- macOS and Windows build helpers now validate upstream `qmc-decrypt` with `--help`.
- `BundledProprietaryAudioAdapterRegistry` now probes direct `qmc-decrypt` with `--help` and reports `qmc-decrypt (version unavailable)`.
- QMC adapter docs now distinguish the FrameLean wrapper `--version` contract from the direct upstream `qmc-decrypt` contract.

## Verification

- `git diff --check`
- `flutter test test/bundled_proprietary_audio_adapter_registry_test.dart`
- `scripts/build/build_qmc_decrypt_macos_arm64.sh`
