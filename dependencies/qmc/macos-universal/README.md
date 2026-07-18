# macOS Universal 2 QMC Adapter

FrameLean packages a QMC adapter from this directory only when the executable
contains both `x86_64` and `arm64` slices.

```bash
scripts/build/build_qmc_decrypt_macos_universal.sh
```

QMC support remains optional. A missing Universal adapter must not cause a
single-architecture helper to be bundled.
