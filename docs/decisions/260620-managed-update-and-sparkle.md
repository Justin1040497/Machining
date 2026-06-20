# 260620 托管更新配置与 macOS 手动 DMG 更新边界

## 状态

有效。

## 决策

- 客户端更新配置由只读配置快照承载，应用启动时读取，运行中更新流程使用内存快照。
- 托管配置优先来自 macOS MDM managed preferences 和 `/Library/Application Support/FrameLean` 下的系统级 JSON，以及 Windows `HKLM\Software\Policies\FrameLean` 和 `%ProgramData%\FrameLean` 下的系统级 JSON。
- 普通用户可写配置文件视为不可信并忽略；隐藏文件只用于减少误触，不作为安全边界。
- Windows 自动更新平台为 `windows-installer`，便携 `windows-x64` ZIP 只作为手动下载和后台留存包。
- Windows 下载包在 SHA-256 后进行 Ed25519 验签；受信任公钥由发布构建内置，托管配置只能选择 key id。
- macOS 默认不走 Sparkle 自动更新。Flutter 使用与 Windows 相同的 JSON latest / ticket 协议发现 `macos-universal2`，展示版本日志，下载 DMG 到用户下载目录，并打开 DMG 所在位置由用户手动安装。
- Sparkle 2 代码和服务端 `/api/v1/sparkle/*` 作为未来可选路线保留；只有构建显式启用 `FRAMELEAN_USE_SPARKLE_UPDATES=true` 且产物具备 Sparkle 签名时才进入 appcast 路线。

## 影响

- 发布 `macos-universal2` DMG 时服务端只强制校验文件名、size、SHA-256 和 COS 对象长度；Sparkle EdDSA 签名可选，缺少签名时 appcast 不输出该版本 item。
- 客户端可见 `windows-installer` 缺少 Ed25519 签名时，服务端仍禁止发布。
- 正式 Windows 构建必须注入更新服务地址和验签公钥；macOS 手动 DMG 路线只需要注入更新服务地址，Apple Developer ID 证书不是检查更新 / 下载 DMG 的前置条件。

## 关联事实

- `lib/app/providers/app_update_provider.dart`
- `macos/Podfile`
- `server/src/main/kotlin/com/framelean/backend/service/UpdateService.kt`
- `server/src/main/kotlin/com/framelean/backend/service/ReleaseService.kt`
- `server/admin-web/src/releaseArtifacts.ts`
