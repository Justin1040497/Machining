# v1.2.1 Admin Web 版本管理

## 版本事实

独立 [FrameLean-Backend](https://github.com/zhouycheng/FrameLean-Backend) 后台使用 RuoYi-Vue-Plus 5.X + plus-ui 5.X。`ruoyi-admin` 是后端入口，`ruoyi-modules/ruoyi-framelean` 承载更新业务，`admin-web` 承载管理页面。RuoYi 负责账号密码登录、菜单、角色、权限和操作日志；`/api/v1/admin/**` 同时接受 RuoYi / Sa-Token 登录态和脚本用 `X-Api-Key`。

旧 React Admin、唯一管理员主密码、challenge 签名登录和 `admin_auth_config` 认证流已经废弃；`admin_auth_config` 仅作为历史表保留。

## 当前发布工作流

- 发布版本页支持创建 draft、编辑构建号、把 Markdown / 文本版本日志上传到 COS、填写 GitHub / Gitee / 备用下载地址、发布和删除版本。
- 当前默认交付方式是外部下载地址。创建或编辑 draft 时可填写一个或多个 HTTP(S) 下载页；客户端按实际存在的地址展示按钮。
- Admin 明确提示“客户端只展示更新日志和下载入口，不再直接下载 EXE / DMG / ZIP”。
- COS 上传 URL、分片上传、制品要求和 package 登记 UI 由 `enableArtifactUpload = false` 暂时隐藏；后端 API 和数据结构继续保留，便于未来重新启用。
- 发布动作只允许 draft 切换为 `published`；已发布版本不可继续修改构建号、日志和下载地址。
- 删除版本时，仍会按登记数据清理日志或 package COS 对象及其依赖记录；COS 删除失败时数据库记录保留，便于重试。

## 发布门禁

当前默认发布校验为：

- 版本日志正文或已上传日志文件至少存在一种。
- 没有 package 时，GitHub、Gitee 或备用下载地址至少存在一个。
- 下载地址必须是具有 host 的 HTTP(S) URL。
- package requirement 当前全部为非必填，历史缺包版本不需要伪造 Windows 安装器或 macOS DMG。

保留 package 路线的校验仍然有效：

| 平台 | 架构 | 当前是否必填 | 客户端可见 | 文件 | 签名 |
| --- | --- | --- | --- | --- | --- |
| `windows-installer` | `x64` | 否 | 是 | `.exe` Inno Setup 安装器 | 登记后必须为 `keyId:base64` Ed25519 签名 |
| `macos-universal2` | `universal2` | 否 | 是 | `.dmg` Universal 2 | Sparkle 签名可选；填写后必须合法 |
| `windows-x64` | `x64` | 否 | 否 | `.zip` 便携包 | 不强制 |

release 同时存在外部地址和 package 时，客户端仍优先外部地址。要重新启用直接 package 更新，应先打开 Admin 制品 UI，再执行 COS、ticket、签名和真实客户端端到端验收。

## 审计和风控边界

- 更新审计页展示检查更新、下载事件和 IP 屏蔽信息。
- 检查更新和 package ticket 创建读取反代后的真实 IP，并写入审计记录。
- IP 屏蔽可阻断检查更新和 ticket 创建；已签发 COS URL 仍只受自身过期时间约束。
- 运行诊断只展示 COS、Redis、公网 base URL、ticket TTL 和 API key 是否配置，不暴露密钥原文。

## 部署与发布步骤

1. 配置 PostgreSQL、Redis、COS、`SA_TOKEN_JWT_SECRET`、`FRAMELEAN_PUBLIC_BASE_URL`、`FRAMELEAN_API_KEY` 和允许的 CORS 域名。当前 Admin 通过 COS 保存版本日志文件，即使不登记 package 也需要可用的日志上传配置。
2. 在独立后端仓库构建 `ruoyi-admin` 和 `admin-web`，由宝塔或 Nginx 把公网 HTTPS 根域名反代到 API。
3. 用 canonical release 脚本生成 DMG、Windows 安装器和可选 ZIP，把用户下载产物发布到 GitHub、Gitee 或备用站点。
4. 在 Admin 创建 `v1.2.1` draft，保存构建号和版本日志，登记至少一个外部下载页并发布。
5. 验证 `/api/v1/releases/latest`、版本日志列表、外部下载按钮、更新审计和反代真实 IP。
6. 只有明确启用 package 兼容链时，才追加 COS package 登记、`*.update.json` 导入、ticket 和安装 helper 验收。

## 验证范围

- RuoYi 登录态和 `X-Api-Key` 兼容鉴权。
- 创建 draft、上传版本日志、保存构建号与三个外部下载地址、发布和删除版本。
- 日志或下载地址缺失时发布失败，合法外部地址 release 可进入 `/latest`。
- 客户端只展示实际存在的外部按钮，不发起 package ticket。
- 隐藏 package UI 不影响后端兼容 API；重新启用前必须单独验证制品、签名、COS 和删除顺序。
- 更新检查审计、下载审计、运行诊断和 IP 屏蔽分页查询。
