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
| `build/build_ffmpeg_macos_arch.sh` | macOS arm64 / x86_64 | Build the pinned FFmpeg runtime and required codecs for one architecture | `third_party/ffmpeg/macos-{arch}/` |
| `build/build_ffmpeg_macos_universal.sh` | macOS Universal 2 | Merge arm64 and x64 runtime slices | `third_party/ffmpeg/macos-universal/` |
| `build/build_ffmpeg_windows_x64.sh` | Windows x64 (MSYS2) | Build the pinned FFmpeg runtime and required codecs | `third_party/ffmpeg/windows-x64/` |
| `build/build_qmc_decrypt_macos_arch.sh` | macOS arm64 / x86_64 | Build the pinned upstream QMC adapter and copy its license files for one architecture | `third_party/audio_adapters/qmc/macos-{arch}/` |
| `build/build_qmc_decrypt_macos_universal.sh` | macOS Universal 2 | Merge arm64 and x64 QMC adapter slices | `third_party/audio_adapters/qmc/macos-universal/` |
| `build/build_qmc_decrypt_windows.ps1` | Windows x64 | Build the pinned upstream QMC adapter and copy its license files | `third_party/audio_adapters/qmc/windows-x64/` |

These scripts prepare dependencies. They do not package the FrameLean app.

`macos-arm64` and `macos-x64` are architecture-specific build inputs. They are
not separate user downloads. The release app consumes only
`third_party/ffmpeg/macos-universal`, and the final public macOS artifact remains
one Universal 2 DMG. An Apple Silicon Mac cannot create the native Intel FFmpeg
slice with the local build script; use the `Build macOS Universal` GitHub
Actions workflow when both native slices are not already available.

## Release Scripts

| Script | Platform | Responsibility | Output |
| --- | --- | --- | --- |
| `release/build_dmg_macos.sh` | macOS | Build and validate the release app and DMG | `build/macos/Build/Products/Release/FrameLean-v*.dmg` and `FrameLean-v*.dmg.update.json` |
| `release/build_windows.ps1` | Windows x64 | Canonical Windows publishing entry point. Builds the release directory once, compiles the updater helper, bundles and validates all runtimes, then creates both the portable zip and Inno Setup installer by default | `build/windows/x64/runner/FrameLean-v*-windows-x64.zip` and `build/windows/x64/installer/FrameLean-v*-windows-x64-setup.exe` |

Use `build_windows.ps1` for a normal Windows release:

```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1
```

正式执行前必须提供 `FRAMELEAN_UPDATE_BASE_URL`、`FRAMELEAN_RELEASE_KEY_ID`、`FRAMELEAN_RELEASE_PUBLIC_KEY` 和仅存在于本机或 CI Secret 的 `FRAMELEAN_RELEASE_PRIVATE_KEY_FILE`。脚本会为安装器生成 `*.update.json`，私钥不会进入安装包。

The default command creates both distribution artifacts from one Flutter build.
Pass `-SkipZip` or `-SkipInstaller` only when a single artifact is explicitly
needed. `-IsccPath` can select a non-default Inno Setup compiler.

macOS 手动 DMG 更新路线必须设置 `FRAMELEAN_UPDATE_BASE_URL`，脚本会把它写入 Flutter dart-define，客户端通过 JSON latest / ticket 下载 DMG 到用户下载目录。默认脚本会为 DMG 生成不带签名的 `*.update.json`，供 Admin Web 核对 file / size / SHA-256。仅当要启用 Sparkle appcast 自动更新时，额外设置 `FRAMELEAN_USE_SPARKLE_UPDATES=true`、`FRAMELEAN_REQUIRE_SPARKLE_SIGNATURE=true`、`FRAMELEAN_SPARKLE_FEED_URL` 和 `FRAMELEAN_SPARKLE_PUBLIC_ED_KEY`，并传入启用签名、公证的 dmg 参数；脚本只在 App 签名、DMG 公证装订和 `sign_update` 全部通过后生成带 Sparkle 签名的 `*.update.json`。

正常发布给用户的安装包可以只保留 Windows 安装器
`FrameLean-v*-windows-x64-setup.exe` 和 macOS
`FrameLean-v*.dmg`。Windows 便携 ZIP 是额外留存成果物，`*.update.json` 是
Admin Web 发布校验元数据，都不是新的平台安装包。

GitHub Actions 打包需要配置以下 Variables / Secret，否则 workflow 会失败，避免产出缺少更新配置的安装包：

```text
Variables:
FRAMELEAN_UPDATE_BASE_URL
FRAMELEAN_RELEASE_KEY_ID
FRAMELEAN_RELEASE_PUBLIC_KEY

Secrets:
FRAMELEAN_RELEASE_PRIVATE_KEY
```

Sparkle 相关 Variables 只在显式启用 Sparkle 自动更新路线时需要；默认 macOS DMG 更新路线不依赖 Apple Developer ID 证书或 Sparkle 公钥。

`FRAMELEAN_RELEASE_PRIVATE_KEY` 保存 Windows 更新签名用的 32-byte Ed25519 seed 或其 base64 文本；workflow 会写入 runner 临时文件并通过 `FRAMELEAN_RELEASE_PRIVATE_KEY_FILE` 传给 Windows 发布脚本。

## Signing Tool

`tool/sign_windows_update.dart` generates the Windows `*.update.json`
metadata for a built installer. It requires:

```bash
dart run tool/sign_windows_update.dart \
  --input <setup.exe>          \
  --private-key <32-byte-seed> \
  --key-id <key-id>            \
  --public-key <base64-pubkey>
```

The tool outputs a JSON file with `sha256`, `size`, and an
`ed25519Signature`, consumed by Admin Web to publish the release.

CI runs this automatically; the manual path above is only needed when
CI is unavailable or the signing key is held offline.

## Installer Definitions

Installer definitions and uninstall helpers live under `installer/`, rather
than `scripts/`, because they are packaged resources:

```text
installer/macos/FrameLean-Clean-Uninstall.command
installer/windows/FrameLean-Clean-Uninstall.ps1
installer/windows/FrameLean.iss
```
