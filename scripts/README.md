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

正式执行前必须提供 `FRAMELEAN_UPDATE_BASE_URL`、`FRAMELEAN_RELEASE_KEY_ID`、`FRAMELEAN_RELEASE_PUBLIC_KEY` 和仅存在于本机或 CI Secret 的 `FRAMELEAN_RELEASE_PRIVATE_KEY_FILE`。脚本会为安装器生成 `*.update.json`，私钥不会进入安装包。

The default command creates both distribution artifacts from one Flutter build.
Pass `-SkipZip` or `-SkipInstaller` only when a single artifact is explicitly
needed. `-IsccPath` can select a non-default Inno Setup compiler.

macOS 可发布构建设置 `FRAMELEAN_REQUIRE_SPARKLE_SIGNATURE=true`、`FRAMELEAN_SPARKLE_FEED_URL` 和 `FRAMELEAN_SPARKLE_PUBLIC_ED_KEY`，并传入启用签名、公证的 dmg 参数。脚本只在 App 签名、DMG 公证装订和 `sign_update` 全部通过后生成 `*.update.json`；无签名本地 DMG 不生成可发布元数据。

GitHub Actions 打包需要配置以下 Variables / Secret，否则 workflow 会失败，避免产出缺少更新配置的安装包：

```text
Variables:
FRAMELEAN_UPDATE_BASE_URL
FRAMELEAN_RELEASE_KEY_ID
FRAMELEAN_RELEASE_PUBLIC_KEY
FRAMELEAN_SPARKLE_FEED_URL
FRAMELEAN_SPARKLE_PUBLIC_ED_KEY

Secrets:
FRAMELEAN_RELEASE_PRIVATE_KEY
```

`FRAMELEAN_RELEASE_PRIVATE_KEY` 保存 Windows 更新签名用的 32-byte Ed25519 seed 或其 base64 文本；workflow 会写入 runner 临时文件并通过 `FRAMELEAN_RELEASE_PRIVATE_KEY_FILE` 传给 Windows 发布脚本。

## Installer Definitions

Installer definitions and uninstall helpers live under `installer/`, rather
than `scripts/`, because they are packaged resources:

```text
installer/macos/FrameLean-Clean-Uninstall.command
installer/windows/FrameLean-Clean-Uninstall.ps1
installer/windows/FrameLean.iss
```
