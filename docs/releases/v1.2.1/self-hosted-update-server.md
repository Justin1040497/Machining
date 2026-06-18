# v1.2.1 自托管更新服务端

## 版本事实

FrameLean server v1.0.0 使用 Kotlin Spring Boot、PostgreSQL、Flyway、MyBatis-Plus、Redis 和腾讯云 COS 承担自托管更新服务。公开客户端接口提供检查更新、版本日志、下载 ticket 创建和解析；管理接口负责 release / package 长期事实和对象存储上传授权。

公开客户端接口集中在 `/api/v1/releases/*`：

- `GET /latest` 根据当前 build、channel 和 platform 查找可用发布。
- `GET /{version}/notes` 返回 Markdown 版本日志。
- `GET /notes` 返回已发布版本日志列表。
- `POST /download-ticket` 创建 Redis 短期下载票据。
- `POST /download-ticket/{ticketId}/resolve` 解析票据并签发 COS 预签名下载 URL。
- `POST /{version}/packages/{platform}/ticket` 保留旧客户端兼容路径。

## 数据边界

- PostgreSQL 保存长期事实：`releases`、`release_packages`、`release_artifact_requirements`、`download_events`、`update_check_events`、`ip_block_rules` 和 `admin_auth_config`。
- Redis 只保存短期协作状态：下载 ticket、latest cache 和限流计数。Redis 数据丢失后可以重建，不应作为 release、package 或审计的唯一来源。
- COS 桶保持私有读写，客户端和 Admin Web 都只通过服务端签发的预签名 URL 访问对象。
- `release_packages.client_visible` 用来区分客户端可见包和后台留存包。Windows 直装版留存包不会进入客户端 latest 查询和下载 ticket。

## 发布校验

服务端发布 release 前校验：

- 版本日志非空。
- 必填平台成果物存在。
- package 文件名、COS object key、size 和 SHA-256 合法。
- Windows 直装版成果物在服务端归一化为可选，不阻塞客户端更新包发布。

检查更新时按平台可见包过滤，避免“某个平台没有包的新版本”挡住旧平台可用版本。

## 部署边界

- `FRAMELEAN_UPDATE_BASE_URL` 面向客户端构建配置，应指向公网根域名，例如 `https://framelean.zhoust.cn`。
- 宝塔单容器部署时不能只看 `/api/v1/health` 或 `docker compose config`。需要检查运行中 API 容器的实际环境变量；如果日志仍显示 `localhost:5432`，通常说明容器创建时没有带上 `DB_HOST=postgres` 等配置。
- 宝塔形态下推荐 PostgreSQL / Redis 继续由 Compose 管理，API 容器加入同一 Docker network 后绑定到 `127.0.0.1`，由宝塔 / Nginx 反代到公网域名。
- 不要在含生产数据的部署上随意执行 `docker compose down -v`，该命令可能删除 PostgreSQL 数据卷。

## 验证范围

- `ReleaseService.findPublishedLatest` 按 channel、build、platform 和 `client_visible` 过滤。
- `UpdateService.checkForUpdate` 记录检查审计并返回正确包信息。
- 下载 ticket 创建写入 Redis，resolve 时签发 COS 预签名 URL 并写入下载事件。
- IP 屏蔽能阻断检查更新和 ticket 创建。
- 发布后清理 latest cache，避免客户端继续看到旧缓存。

