# FrameLean Scripts

The scripts are split by responsibility:

```text
scripts/
  build/      Build third-party platform runtimes.
  release/    Build and package FrameLean release artifacts.
```

## Build Scripts

| Script | Platform | Responsibility | Output |
| --- | --- | --- | --- |
| `build/build_ffmpeg_macos_arm64.sh` | macOS arm64 | Build the pinned FFmpeg runtime and required codecs | `third_party/ffmpeg/macos-arm64/` |
| `build/build_qmc_decrypt_macos_arm64.sh` | macOS arm64 | Build the pinned upstream QMC adapter and copy its license files | `third_party/audio_adapters/qmc/macos-arm64/` |
| `build/build_qmc_decrypt_windows.ps1` | Windows x64 | Build the pinned upstream QMC adapter and copy its license files | `third_party/audio_adapters/qmc/windows-x64/` |

These scripts prepare dependencies. They do not package the FrameLean app.

## Release Scripts

| Script | Platform | Responsibility | Output |
| --- | --- | --- | --- |
| `release/build_dmg_macos.sh` | macOS | Build and validate the release app and DMG | `build/macos/Build/Products/Release/FrameLean-v*.dmg` |
| `release/build_windows.ps1` | Windows x64 | Canonical Windows publishing entry point. Builds the release directory once, compiles the updater helper, bundles and validates all runtimes, then creates both the portable zip and Inno Setup installer by default | `build/windows/x64/runner/FrameLean-v*-windows-x64.zip` and `build/windows/x64/installer/FrameLean-v*-windows-x64-setup.exe` |

Use `build_windows.ps1` for a normal Windows release:

```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1
```

The default command creates both distribution artifacts from one Flutter build.
Pass `-SkipZip` or `-SkipInstaller` only when a single artifact is explicitly
needed. `-IsccPath` can select a non-default Inno Setup compiler.

## Installer Definitions

Installer definitions and uninstall helpers live under `installer/`, rather
than `scripts/`, because they are packaged resources:

```text
installer/macos/FrameLean-Clean-Uninstall.command
installer/windows/FrameLean-Clean-Uninstall.ps1
installer/windows/FrameLean.iss
```
