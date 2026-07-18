# FrameLean QMC Audio Adapter

This directory is reserved for the external QMC adapter used by FrameLean to prepare `.mgg` and `.mflac` inputs.

FrameLean accepts either a FrameLean wrapper adapter or the upstream `qmc-decrypt` executable:

```text
framelean-qmc-adapter
framelean-qmc-adapter.exe
qmc-decrypt
qmc-decrypt.exe
```

Expected FrameLean wrapper command contract:

```text
framelean-qmc-adapter --input <source> --output-dir <temporary-dir> --format <qmcMgg|qmcMflac>
framelean-qmc-adapter --version
```

Direct `qmc-decrypt` command contract:

```text
qmc-decrypt <source> <temporary-dir>
```

The pinned upstream `qmc-decrypt` binary does not expose `--version`; FrameLean probes it with `--help` and reports its version as unavailable. `qmc-decrypt` only supports the variants supported by its upstream project. `mgg1` and `mflac0` require an `ekey`; FrameLean does not provide an ekey UI yet, so those inputs should fail with a readable adapter error until that product boundary is added.

Placement for development:

```text
build/dependencies/qmc/macos-arm64/framelean-qmc-adapter
build/dependencies/qmc/macos-x64/framelean-qmc-adapter
build/dependencies/qmc/macos-universal/framelean-qmc-adapter
build/dependencies/qmc/windows-x64/framelean-qmc-adapter.exe
build/dependencies/qmc/macos-arm64/qmc-decrypt
build/dependencies/qmc/macos-x64/qmc-decrypt
build/dependencies/qmc/macos-universal/qmc-decrypt
build/dependencies/qmc/windows-x64/qmc-decrypt.exe
```

Build helpers:

```text
scripts/build/build_qmc_decrypt_macos_arch.sh
scripts/build/build_qmc_decrypt_macos_universal.sh
scripts/build/build_qmc_decrypt_windows.ps1
```

The helper scripts build `bczhc/qmc-decrypt` at commit `12d758a6a08635b4ab85b6dca05025fdbcc26520`, merge the macOS slices, and copy its license files next to the runtime.

Adapter requirements:

- Use only local files.
- Do not call network services or music platform APIs.
- Write decoded standard audio only under the supplied output directory.
- Include upstream source, build instructions, license, and notice material before packaging.

The macOS release build packages an adapter only from `macos-universal`; a
single-architecture adapter is never copied into the Universal app.
