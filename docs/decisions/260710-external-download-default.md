# 260710 外部下载地址优先的更新发布边界

## 状态

有效。

## 决策

- 当前公开更新流程以 GitHub、Gitee 或备用下载地址为默认交付方式。服务端 `latest` 响应可以只返回外部下载地址，不要求同时返回安装包元数据。
- 客户端发现任一外部下载地址时，只展示版本日志和对应下载入口，不创建 download ticket，也不直接下载或安装 EXE、DMG、ZIP。
- Admin Web 默认展示下载地址登记，暂时隐藏 COS 制品上传、制品要求和制品登记界面。
- release 没有登记 package 时，发布门禁要求版本日志非空，并且至少存在一个合法的 HTTP(S) 下载地址。
- 原 package 自更新链继续保留：服务端仍支持 release package、COS、download ticket 和 Sparkle appcast；客户端仍保留断点下载、Windows Ed25519 验签 / updater helper、macOS 私有更新缓存和手动 DMG 打开能力。
- 只要 release 登记了 package，服务端仍按平台、扩展名、size、SHA-256、签名和 COS 对象长度校验；但当前三个 package 类型都不再是发布必填项。
- macOS / Windows canonical release 脚本和 GitHub Actions 继续要求更新地址、Windows 密钥和签名配置完整，并继续生成 `*.update.json`。这是对保留 package 链的 fail-closed 保护，不代表当前 Admin 默认发布必须登记 package。

## 影响

- 用户默认从外部下载页手动获取和安装新版，客户端不会因为服务端保留 package 能力而自动进入下载安装流程。
- `v1.2.1` Release 文档需要把外部下载入口描述为当前默认，把直接 package 更新描述为保留能力和后续可重新启用的兼容路径。
- 生产发布至少要验证版本日志、GitHub / Gitee / 备用地址、客户端外链打开和服务端 latest cache；COS package 上传、download ticket、Windows helper 和 Sparkle appcast 只在显式启用 package 路线时做端到端验收。
- 260620 决策中的托管配置安全边界、Windows 签名校验和 macOS / Sparkle 能力继续有效；“Windows / macOS package 是当前默认发布必填项”的口径由本决策取代。

## 关联事实

- `lib/app/providers/app_update_provider.dart`
- `lib/app/presentation/widgets/update_notice_dialog.dart`
- `lib/domain/value_objects/app_release_info.dart`
- 独立 [FrameLean-Backend](https://github.com/zhouycheng/FrameLean-Backend) 仓库中的更新服务与 Admin Web
- `scripts/release/build_dmg_macos.sh`
- `scripts/release/build_windows.ps1`
