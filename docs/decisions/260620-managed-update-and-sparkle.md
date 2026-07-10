# 260620 托管更新配置与 macOS 手动 DMG 更新边界

## 状态

部分被 `260710-external-download-default.md` 取代。

2026-07-10 起，公开发布默认展示 GitHub、Gitee 或备用下载入口，不再要求 release 必须登记 Windows / macOS package。本文中的托管配置安全、package 验签、Windows helper、macOS 手动 DMG 和 Sparkle 可选路线继续有效；直接 package 更新只在 release 没有外部下载地址且提供完整包元数据时使用。

## 决策

- 客户端更新配置由只读配置快照承载，应用启动时读取，运行中更新流程使用内存快照。
- 托管配置优先来自 macOS MDM managed preferences 和 `/Library/Application Support/FrameLean` 下的系统级 JSON，以及 Windows `HKLM\Software\Policies\FrameLean` 和 `%ProgramData%\FrameLean` 下的系统级 JSON。
- 普通用户可写配置文件视为不可信并忽略；隐藏文件只用于减少误触，不作为安全边界。
- 保留的 Windows package 自动更新平台为 `windows-installer`，便携 `windows-x64` ZIP 只作为手动下载和后台留存包。
- Windows 下载包在 SHA-256 后进行 Ed25519 验签；受信任公钥由发布构建内置，托管配置只能选择 key id。
- 保留的 macOS package 路线不走 Sparkle 自动更新。Flutter 使用与 Windows 相同的 JSON latest / ticket 协议发现 `macos-universal2`，展示版本日志，下载 DMG 到应用私有目录，并打开 DMG 所在位置由用户手动安装。下载状态持久化到本地 JSON，重启后如 DMG 仍在且 SHA-256 校验通过则自动恢复已下载状态。
- Sparkle 2 代码和服务端 `/api/v1/sparkle/*` 作为未来可选路线保留；只有构建显式启用 `FRAMELEAN_USE_SPARKLE_UPDATES=true` 且产物具备 Sparkle 签名时才进入 appcast 路线。

## 影响

- 登记 `macos-universal2` DMG 时，服务端校验文件名、size、SHA-256 和 COS 对象长度；Sparkle EdDSA 签名可选，缺少签名时 appcast 不输出该版本 item。
- 登记 `windows-installer` 时，缺少 Ed25519 签名仍无法通过 package 校验。
- 正式 Windows 构建必须注入更新服务地址和验签公钥；macOS 手动 DMG 路线只需要注入更新服务地址，Apple Developer ID 证书不是检查更新 / 下载 DMG 的前置条件。

## 关联事实

- `lib/app/providers/app_update_provider.dart`
- `macos/Podfile`
- `docs/decisions/260710-external-download-default.md`
- `server/ruoyi-modules/ruoyi-framelean/src/main/java/org/dromara/framelean/service/UpdateService.java`
- `server/ruoyi-modules/ruoyi-framelean/src/main/java/org/dromara/framelean/service/ReleaseService.java`
- `server/admin-web/src/views/framelean/releases/index.vue`
