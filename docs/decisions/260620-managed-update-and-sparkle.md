# 260620 托管更新配置与 macOS Sparkle 边界

## 状态

有效。

## 决策

- 客户端更新配置由只读配置快照承载，应用启动时读取，运行中更新流程使用内存快照。
- 托管配置优先来自 macOS MDM managed preferences 和 `/Library/Application Support/FrameLean` 下的系统级 JSON，以及 Windows `HKLM\Software\Policies\FrameLean` 和 `%ProgramData%\FrameLean` 下的系统级 JSON。
- 普通用户可写配置文件视为不可信并忽略；隐藏文件只用于减少误触，不作为安全边界。
- Windows 自动更新平台为 `windows-installer`，便携 `windows-x64` ZIP 只作为手动下载和后台留存包。
- Windows 下载包在 SHA-256 后进行 Ed25519 验签；受信任公钥由发布构建内置，托管配置只能选择 key id。
- macOS 自动更新交给 Sparkle 2，Flutter 只通过 MethodChannel 触发手动检查和执行重启前准备；Sparkle 负责 appcast、下载、EdDSA 校验、安装和重启提示。
- 服务端单独提供 `/api/v1/sparkle/appcast` 和 `/api/v1/sparkle/download/{version}`，不把 Sparkle XML 协议混入 JSON latest / ticket 协议。

## 影响

- 发布 macOS DMG 前必须完成签名和公证，再运行 Sparkle `sign_update` 并生成统一的 `*.update.json` 元数据。
- 客户端可见包缺少 Ed25519 / Sparkle 签名时，服务端禁止发布。
- 正式 macOS 构建必须注入 Sparkle `SUPublicEDKey` 和默认 `SUFeedURL`，受管理设备可通过托管配置覆盖 appcast URL。

## 关联事实

- `lib/app/providers/app_update_provider.dart`
- `macos/Podfile`
- `server/src/main/kotlin/com/framelean/backend/service/UpdateService.kt`
- `server/admin-web/src/releaseArtifacts.ts`
