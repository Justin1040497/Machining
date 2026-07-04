# v1.2.1 Admin Web 版本管理

## 版本事实

FrameLean server 当前后台已迁移到 RuoYi-Vue-Plus 5.X + plus-ui 5.X。`ruoyi-admin` 是后端入口模块，`ruoyi-modules/ruoyi-framelean` 承载 FrameLean 自托管更新业务，`server/admin-web` 承载 plus-ui 后台页面。RuoYi 负责后台登录、菜单、角色、权限和操作日志，FrameLean 模块继续提供公开更新 API、发布版本、更新审计、运行诊断、COS 私有桶预签名分发、Redis 短期票据 / latest cache / 限流计数，以及 PostgreSQL 发布和审计业务表。

旧版 React + Vite + Ant Design Admin、唯一管理员主密码、challenge 签名登录和 `admin_auth_config` 认证流已经废弃；`admin_auth_config` 仅作为历史表保留。当前 `/api/v1/admin/**` 兼容两种访问方式：浏览器后台使用 RuoYi / Sa-Token 登录态，脚本和自动化可继续使用 `X-Api-Key`，其中 `FRAMELEAN_API_KEY` 只用于兼容 API Key，不再用于首次初始化管理员。

## 版本管理边界

- 管理端提供发布版本、更新审计和运行诊断三个 FrameLean 页面。发布版本页支持创建 draft release、编辑构建号和版本日志、生成 COS 上传 URL、登记平台制品元数据、发布和删除登记版本。
- 大文件上传通过服务端 COS 预签名 URL 或分片上传接口完成，前端只拿预签名 URL，不持有 COS 密钥。
- 草稿详情页展示基础信息、发布要求、版本日志、已登记 package、客户端可见状态和累计下载信息。
- 发布动作只支持将草稿切换为 `published`；已发布版本的日志、构建号和制品不在页面内编辑。
- 删除登记版本会先删除该版本日志和所有登记 package 对应的 COS 对象，再删除下载事件、package、requirements 和 release 记录；如果 COS 删除失败，数据库记录保留，便于重试。

## 制品要求和历史版本缺包策略

当前自动更新发布校验以客户端可安全消费为边界：

| 平台 | 架构 | 是否必填 | 客户端可见 | 文件 | 签名 |
| --- | --- | --- | --- | --- | --- |
| `windows-installer` | `x64` | 是 | 是 | `.exe` Inno Setup 当前用户安装器 | 必须为 `keyId:base64` Ed25519 签名 |
| `macos-universal2` | `universal2` | 是 | 是 | `.dmg` Universal 2 | 手动 DMG 路线不强制；Sparkle appcast 需要 64 字节 EdDSA 签名 |
| `windows-x64` | `x64` | 否 | 否 | `.zip` 便携包 | 不强制 |

历史版本不能为了通过校验伪造缺失包。像 `v1.0.0`、`v1.1.0`、`v1.1.5` 等只有 DMG、缺失 Windows `.exe` 安装器的版本，应按归档版本处理：可以把 DMG 和版本日志上传到 COS 并在 Admin 草稿中登记，保留为内部可查询的历史制品清单，但不要切换为 `published`，否则当前发布校验会阻止发布。`published` 状态只保留给同时满足 `windows-installer` 和 `macos-universal2` 自动更新要求的版本。

如果后续需要让旧版本出现在公开版本日志页但不参与 `/latest` 自动更新，应先扩展数据模型和服务端状态，例如新增 `archived` / `notes_only` 状态或单独的公开归档接口；不要把缺包历史版本塞进当前 `published` 通道。

## 审计和风控边界

- 下载统计页展示总下载、检查更新、下载 IP、检查 IP 和当前封禁 IP。
- 检查更新和下载 ticket 创建都读取反代后的真实 IP，并写入审计记录。
- IP 屏蔽规则用于阻断检查更新和下载 ticket 创建；已签发但尚未过期的 COS 预签名 URL 仍受其自身过期时间约束。
- `/api/v1/admin/*` 同时支持脚本用 `X-Api-Key` 和 RuoYi 登录态；鉴权失败返回兼容 JSON 错误，便于脚本判断。

## 部署方案

推荐按“当前可自动更新版本”和“历史归档版本”分两条线部署。

1. 准备服务端运行环境：PostgreSQL、Redis、COS 私有桶、`SA_TOKEN_JWT_SECRET`、`FRAMELEAN_PUBLIC_BASE_URL`、`FRAMELEAN_API_KEY` 和 COS 凭据。生产环境 `FRAMELEAN_PUBLIC_BASE_URL` 必须是公网 HTTPS 根地址；旧 `FRAMELEAN_UPDATE_BASE_URL` 只作为兼容 fallback。
2. 部署 RuoYi 后台：构建 `ruoyi-admin` 和 `server/admin-web`，让 API 容器加入 PostgreSQL / Redis 所在网络，由宝塔或 Nginx 反代公网域名到 API。部署后先看运行中容器实际 env，不能只看 `/api/v1/health`。
3. 发布当前自动更新版本：用 Windows / macOS release 脚本生成安装器、DMG 和 `.update.json`；在 Admin 中创建草稿，上传 `windows-installer` 和 `macos-universal2` 到 COS，登记 `size`、`sha256`、Windows Ed25519 签名和可选 macOS Sparkle 签名，确认校验通过后发布。
4. 导入历史版本：为 `v1.0.0`、`v1.1.0`、`v1.1.5` 等缺 Windows `.exe` 的版本单独建立草稿或外部清单，只登记已有 DMG 和日志，保持 `draft`，不发布到客户端自动更新通道。若只有 Windows ZIP，也同样作为后台留存包，不替代 `windows-installer`。
5. 验证公开链路：检查 `/api/v1/releases/latest?platform=windows-installer`、`/api/v1/releases/latest?platform=macos-universal2`、`/api/v1/releases/notes`、下载 ticket 创建和 resolve、COS 预签名下载、更新审计、下载审计和 IP 屏蔽。

## 验证范围

- RuoYi 登录态和 `X-Api-Key` 兼容鉴权。
- 创建草稿、生成 COS 上传 URL、注册 package、保存构建号和日志、发布和删除登记版本。
- 缺失 `windows-installer` 的历史版本保持 draft / 归档，不进入 `/latest` 自动更新结果。
- 版本删除时的 COS object key 安全校验、对象去重删除和数据库依赖行删除顺序。
- 下载统计、检查更新审计、下载审计和 IP 屏蔽分页查询。
