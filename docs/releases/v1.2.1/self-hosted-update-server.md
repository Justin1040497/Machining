# v1.2.1 更新服务端

## 版本事实

FrameLean server 当前使用 RuoYi-Vue-Plus 5.X + plus-ui 5.X、Java Spring Boot、PostgreSQL、Flyway、MyBatis-Plus、Redis 和腾讯云 COS。`ruoyi-admin` 是入口模块，`ruoyi-modules/ruoyi-framelean` 保存更新业务，`server/admin-web` 提供后台页面。

当前公开发布以版本日志和外部下载地址为默认。release 可保存 GitHub、Gitee 和备用下载地址；客户端检查更新时优先消费这些地址。原 release package、COS、download ticket 和 Sparkle appcast 能力继续保留，但 package 不再是发布必填项。

公开客户端接口集中在 `/api/v1/releases/*`：

- `GET /latest` 根据当前 build、channel 和 platform 查找可用发布，并返回可选 package 元数据及外部下载地址。
- `GET /{version}/notes` 返回 Markdown 版本日志。
- `GET /notes` 返回已发布版本日志列表。
- `POST /download-ticket`、`POST /download-ticket/{ticketId}/resolve` 和旧版 package ticket 路径保留给 package 兼容链。

macOS Sparkle 接口集中在 `/api/v1/sparkle/*`。appcast 只包含具备 Sparkle 签名的 `macos-universal2` package；无签名或只登记外部地址的 release 仍可通过 JSON latest 展示版本日志和外部入口。

## 数据边界

- PostgreSQL 保存 release、外部下载地址、可选 package、版本日志、更新检查、下载事件、IP 屏蔽和 RuoYi 后台事实。
- Redis 保存 latest cache、package download ticket 和限流计数。Redis 数据丢失后可以重建，不是 release 或审计的唯一来源。
- COS 可以保存上传的版本日志文件和可选 package。外部下载地址模式不要求把安装包上传 COS。
- `release_packages.client_visible` 继续区分客户端 package 与后台留存包；只有 package 兼容链会消费这些字段。

## 发布校验

服务端发布 release 前执行以下规则：

- 版本日志正文或日志文件至少存在一种；使用日志文件时，COS 对象必须存在且非空。
- 没有登记 package 时，GitHub、Gitee 或备用下载地址至少存在一个，并且必须是带 host 的 HTTP(S) URL。
- 当前 `windows-x64`、`windows-installer` 和 `macos-universal2` requirement 都规范化为非必填；Admin 提交的 required / clientVisible 不改变服务端平台规范。
- 只要登记 package，仍校验平台、架构、扩展名、object key、正数 size、64 位十六进制 SHA-256 和 COS 对象长度。
- 登记 `windows-installer` 时 Ed25519 必须是 `keyId:base64` 且解码为 64 字节；`macos-universal2` Sparkle 签名可选，但填写后必须是 64 字节签名。
- release 同时包含外部地址和 package 时仍可发布；客户端按外部地址优先策略绕过 package 下载。

`/latest` 只有在 release 至少拥有当前平台 package 或任一外部下载地址时才返回更新。外部地址 release 的 package 字段使用空值占位，客户端不得据此创建 ticket。

## Admin 与部署边界

- Admin Web 默认展示版本、构建号、日志和 GitHub / Gitee / 备用地址编辑；COS package 上传、requirements 和 package 登记界面暂时隐藏，后端兼容 API 仍保留。
- `FRAMELEAN_PUBLIC_BASE_URL` 是服务端公开根地址，生产环境必须使用 HTTPS；旧 `FRAMELEAN_UPDATE_BASE_URL` 只作为 fallback。
- 宝塔单容器部署时需要检查运行中 API 容器的真实 DB、Redis 和公网地址环境变量，不能只依赖 `/api/v1/health` 或静态 Compose 输出。
- PostgreSQL / Redis 可继续由 Compose 管理，API 绑定到受控网络或本机端口后由宝塔 / Nginx 反代。
- 不要在含生产数据的部署上执行 `docker compose down -v`。

## 验证范围

- 仅日志 + 外部地址的 draft 可以发布，三类外部地址逐项校验并由 `/latest` 返回。
- 没有 package 且没有外部地址时发布失败；日志缺失或日志对象不可读时发布失败。
- 客户端按 platform 检查外部地址 release 时得到更新；Redis latest cache 在发布或修改后保持一致。
- package 兼容链继续验证平台、签名、COS 对象、ticket、resolve、下载审计和 Sparkle appcast。
- RuoYi 登录态与 `X-Api-Key` 兼容鉴权、更新审计、下载审计、运行诊断和 IP 屏蔽正常工作。
