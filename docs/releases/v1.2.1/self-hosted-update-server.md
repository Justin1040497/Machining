# v1.2.1 自托管更新服务端

## 版本事实

FrameLean server v1.0.0 使用 Kotlin Spring Boot、PostgreSQL、Flyway、MyBatis-Plus、Redis 和腾讯云 COS 承担自托管更新服务。公开客户端接口提供检查更新、版本日志、下载 ticket 创建和解析；管理接口负责 release / package 长期事实和对象存储上传授权。

公开客户端 JSON 更新接口集中在 `/api/v1/releases/*`：

- `GET /latest` 根据当前 build、channel 和 platform 查找可用发布。
- `GET /{version}/notes` 返回 Markdown 版本日志。
- `GET /notes` 返回已发布版本日志列表。
- `POST /download-ticket` 创建 Redis 短期下载票据。
- `POST /download-ticket/{ticketId}/resolve` 解析票据并签发 COS 预签名下载 URL。
- `POST /{version}/packages/{platform}/ticket` 保留旧客户端兼容路径。

macOS Sparkle 接口集中在 `/api/v1/sparkle/*`：

- `GET /appcast` 按 channel 输出 Sparkle appcast XML。
- `GET /download/{version}` 记录下载审计并 302 到 COS 短期预签名 URL。
- appcast 内的版本日志和下载地址只使用 `FRAMELEAN_PUBLIC_BASE_URL`，不依赖反向代理传入的 Host。
- Sparkle appcast 是可选兼容接口；`macos-universal2` 包没有 Sparkle EdDSA 签名时不会出现在 appcast，但仍可通过 JSON latest / ticket 手动下载 DMG。

## 数据边界

- PostgreSQL 保存长期事实：`releases`、`release_packages`、`release_artifact_requirements`、`download_events`、`update_check_events`、`ip_block_rules` 和 `admin_auth_config`。
- Redis 只保存短期协作状态：下载 ticket、latest cache 和限流计数。Redis 数据丢失后可以重建，不应作为 release、package 或审计的唯一来源。
- COS 桶保持私有读写，客户端和 Admin Web 都只通过服务端签发的预签名 URL 访问对象。
- `release_packages.client_visible` 用来区分客户端可见包和后台留存包。Windows 安装器是客户端可见自动更新包；Windows ZIP 是后台留存 / 手动下载包。

## 发布校验

服务端发布 release 前校验：

- 版本日志非空。
- `windows-installer/x64` 必须是客户端可见 `.exe`，`macos-universal2/universal2` 必须是客户端可见 `.dmg`；`windows-x64/x64` 只能是可选后台留存 `.zip`。客户端提交的 required / clientVisible 不改变这些规则。
- package 文件名、COS object key、正数 size 和 64 位十六进制 SHA-256 合法，COS 对象必须存在且实际长度一致。
- Windows 安装器签名必须是 `keyId:base64` 且解码为 64 字节；macOS 手动 DMG 路线不强制签名，只强制 SHA-256 和对象长度。若提供 Sparkle EdDSA 签名，必须是解码后 64 字节的 base64。
- 缺少任一自动更新制品时禁止发布；Windows ZIP 可缺省，但不能替代安装器。
- Admin Web 可导入构建脚本生成的 `*.update.json`，并在上传前核对平台、文件名、长度、SHA-256；Windows 安装器继续核对签名，macOS 签名可留空。

检查更新时按平台可见包过滤，避免“某个平台没有包的新版本”挡住旧平台可用版本。

## 部署边界

- `FRAMELEAN_UPDATE_BASE_URL` 面向客户端构建配置，应指向公网根域名，例如 `https://framelean.zhoust.cn`。
- `FRAMELEAN_PUBLIC_BASE_URL` 面向服务端 appcast，生产环境必须是公网 HTTPS 根地址；Compose 启动时要求显式配置。只有 localhost / loopback 本地开发允许 HTTP。
- 宝塔单容器部署时不能只看 `/api/v1/health` 或 `docker compose config`。需要检查运行中 API 容器的实际环境变量；如果日志仍显示 `localhost:5432`，通常说明容器创建时没有带上 `DB_HOST=postgres` 等配置。
- 宝塔形态下推荐 PostgreSQL / Redis 继续由 Compose 管理，API 容器加入同一 Docker network 后绑定到 `127.0.0.1`，由宝塔 / Nginx 反代到公网域名。
- 不要在含生产数据的部署上随意执行 `docker compose down -v`，该命令可能删除 PostgreSQL 数据卷。

## 验证范围

- `ReleaseService.findPublishedLatest` 按 channel、build、platform 和 `client_visible` 过滤。
- `UpdateService.checkForUpdate` 记录检查审计并返回正确包信息。
- 下载 ticket 创建写入 Redis，resolve 时签发 COS 预签名 URL 并写入下载事件。
- Sparkle appcast XML 对有签名的 macOS 包输出 buildNumber、shortVersionString、release notes link、DMG enclosure、`sparkle:edSignature` 和 length；无签名 macOS 包不进入 appcast。
- Sparkle 下载 redirect 写入下载事件并返回 COS 短期 URL。
- IP 屏蔽能阻断检查更新和 ticket 创建。
- 发布后清理 latest cache，避免客户端继续看到旧缓存。
