# FrameLean Backend

FrameLean 后端当前迁移到 RuoYi-Vue-Plus 5.X + 官方 plus-ui 5.X：

- `ruoyi-admin` 是 Spring Boot 入口，负责 RuoYi 登录、菜单权限、静态后台和公开更新 API。
- `ruoyi-modules/ruoyi-framelean` 保存更新业务：发布版本、外部下载地址、COS 日志 / 可选制品、短期下载票据、审计和 IP 屏蔽。
- `admin-web` 是 plus-ui 管理端，新增 FrameLean 发布版本、更新审计和运行诊断页面。

## 保持兼容的客户端 API

- `GET /api/v1/health`
- `GET /api/v1/releases/latest`
- `GET /api/v1/releases/{version}/notes`
- `GET /api/v1/releases/notes`
- `POST /api/v1/releases/download-ticket`
- `POST /api/v1/releases/download-ticket/{ticketId}/resolve`
- `POST /api/v1/releases/{version}/packages/{platform}/ticket`
- `GET /api/v1/sparkle/appcast`

## 环境变量

复制 `.env.example` 到 `.env`，至少配置：

```text
DB_PASSWORD=...
REDIS_PASSWORD=...
SA_TOKEN_JWT_SECRET=...
COS_SECRET_ID=...
COS_SECRET_KEY=...
COS_BUCKET=...
COS_REGION=ap-guangzhou
FRAMELEAN_API_KEY=...
FRAMELEAN_PUBLIC_BASE_URL=https://framelean.example.com
FRAMELEAN_ALLOWED_ORIGIN_PATTERNS=https://framelean.example.com
```

`FRAMELEAN_PUBLIC_BASE_URL` 必须是公网根域名，不能配置成 `/api` 子路径。旧环境里的 `FRAMELEAN_UPDATE_BASE_URL` 仍可作为 fallback。
`FRAMELEAN_ALLOWED_ORIGIN_PATTERNS` 是后台和公开 API 的 CORS 白名单，生产环境应只填公网域名；本地开发可额外保留 `http://localhost:*` 和 `http://127.0.0.1:*`。

## 后台登录和安全边界

- 生产入口是公网根域名，例如 `https://framelean.zhoust.cn`，登录页是 `/login`。
- FrameLean 后台只启用 RuoYi / Sa-Token 账号密码登录；注册、短信、邮箱、小程序和社交登录入口均禁用。
- 公开客户端协议只放行 `/api/v1/health`、`/api/v1/releases/**` 和 `/api/v1/sparkle/**`。
- `/api/v1/admin/**` 仅允许 RuoYi 登录态或 `X-Api-Key` 访问；`/system/**`、`/monitor/**`、`/tool/**` 不再作为免登录 API。
- 运行诊断只展示 COS、Redis、公网 base URL、ticket TTL 和 API key 是否配置，不暴露密钥原文。

## 本地运行

```bash
docker compose up --build
```

后台默认监听 `4918`。plus-ui 开发模式使用：

```bash
cd admin-web
npm install
npm run dev
```

开发代理会转发到 `http://localhost:4918`。

## 构建验证

```bash
mvn -pl ruoyi-admin -am -DskipTests package
cd admin-web
npm install
npm run build:prod
```

## 当前发布语义

- 默认在 draft 中上传 Markdown / 文本版本日志，并填写 GitHub、Gitee 或备用下载页。没有登记 package 时，日志和至少一个合法 HTTP(S) 下载地址是发布条件。
- 客户端收到任一外部下载地址后只展示跳转入口，不创建 package ticket，也不直接下载或安装 EXE、DMG、ZIP。
- Admin 当前隐藏 COS package 上传、制品要求和制品登记 UI；后端兼容 API 与数据结构继续保留。
- Release 状态为 `draft`、`published`、`archived`。只有 `draft` 可编辑和发布；归档版本不进入 `/latest`。

保留 package 语义：

- `windows-installer` / `x64`：客户端可见 `.exe`，当前非必填；登记后 Windows Ed25519 签名必填。
- `macos-universal2` / `universal2`：客户端可见 `.dmg`，当前非必填；Sparkle 签名可选。
- `windows-x64` / `x64`：后台留存 / 手动 ZIP，当前非必填且不进入客户端 latest。
- package 存在时仍校验扩展名、size、SHA-256、签名和 COS 对象长度；release 同时包含外部地址和 package 时，客户端仍优先外部地址。
