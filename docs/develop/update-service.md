# 自托管更新服务

## 目标

FrameLean 的应用更新检查不再直接访问 GitHub / Gitee Releases，也不依赖 Cloudflare Workers / R2 作为更新源。

目标架构改为自有服务器托管：

```text
FrameLean 客户端
  -> 自有 Rust 更新服务
  -> 自有服务器上的安装包和更新元数据
```

服务端负责返回最新版本、更新说明、平台安装包地址和校验信息。当前实现使用 HMAC 请求签名保护更新信息接口，并为安装包下载地址生成短期有效的签名 token。

## 仓库布局建议

当前阶段先采用过渡布局：

```text
FrameLean/
  lib/                         当前 Flutter 客户端源码，暂不移动
  macos/
  windows/
  server/
    update-service/            Rust 自有更新服务
  docs/                        产品、架构、开发和发布文档，保持仓库级别
  legal/                       仓库级许可证和第三方声明
  scripts/                     仍服务当前 Flutter 客户端的构建脚本
```

未来如果要迁移成更标准的 monorepo，可以单独做一次机械迁移：

```text
FrameLean/
  client/                      Flutter 桌面客户端
  server/                      后端服务
  docs/                        仓库级文档
  legal/                       仓库级许可证和分发说明
  scripts/                     仓库级自动化脚本；客户端专属脚本再下沉到 client/scripts/
```

不建议现在顺手把 Flutter 工程整体移动到 `client/`，因为会同时影响 Flutter 平台目录、打包脚本、GitHub Actions、README 路径、Xcode / Windows 构建路径和已有测试命令。

## API

当前 Rust 更新服务位于：

```text
server/update-service
```

服务读取 `FRAMELEAN_UPDATE_STORAGE_DIR` 下的 `releases.json`、版本日志和安装包文件。示例存储目录位于：

```text
server/update-service/examples/storage
```

### 健康检查

```text
GET /health
```

响应示例：

```json
{
  "ok": true,
  "service": "framelean-updates"
}
```

### 最新版本

```text
GET /api/v1/updates/check?platform=macos-arm64&current_version=1.1.5
```

响应中只返回是否有新版本、最新版本号，以及继续读取日志和平台包信息的接口地址。客户端在确认有更新后，再请求日志和当前平台安装包信息。

### 版本日志

```text
GET /api/v1/releases/{version}/notes
```

### 平台安装包

```text
GET /api/v1/releases/{version}/packages/{platform}
GET /api/v1/releases/{version}/packages/{platform}/download
```

`/download` 不直接使用 HMAC header，而是要求 `/packages/{platform}` 返回的短期 `token`。token 默认有效期为 30 分钟。

### 鉴权

除 `/health` 和带短期 token 的下载接口外，更新服务接口都要求下面的请求头：

```text
X-FrameLean-Client-Id
X-FrameLean-Timestamp
X-FrameLean-Nonce
X-FrameLean-Signature
```

签名内容为：

```text
METHOD
PATH_WITH_QUERY
TIMESTAMP
NONCE
SHA256(BODY)
```

服务端使用 `FRAMELEAN_UPDATE_HMAC_SECRET` 校验 HMAC-SHA256 签名，同时检查时间窗口和 nonce，降低直接访问和重放请求的风险。这个密钥会通过 `--dart-define` 编进桌面客户端，只能阻挡普通未授权访问，不是 DRM；如果后续要按用户授权控制更新，需要增加 license 或账号 token。

## 服务端配置

运行服务前需要设置：

```text
FRAMELEAN_UPDATE_HMAC_SECRET=<客户端请求签名密钥>
FRAMELEAN_UPDATE_DOWNLOAD_SECRET=<下载 token 签名密钥，可选>
FRAMELEAN_UPDATE_PUBLIC_BASE_URL=https://updates.example.com
FRAMELEAN_UPDATE_STORAGE_DIR=/srv/framelean-updates/storage
FRAMELEAN_UPDATE_BIND_ADDR=127.0.0.1:8080
```

本地运行：

```bash
cargo run --manifest-path server/update-service/Cargo.toml
```

客户端构建时需要写入服务地址和签名密钥：

```bash
flutter build macos \
  --dart-define=FRAMELEAN_UPDATE_BASE_URL=https://updates.example.com \
  --dart-define=FRAMELEAN_UPDATE_HMAC_SECRET=<客户端请求签名密钥>
```

## 发布顺序

1. 打包生成 macOS DMG 和 Windows 安装器。
2. 计算安装包 SHA-256。
3. 将安装包、日志和版本元数据发布到 `FRAMELEAN_UPDATE_STORAGE_DIR`。
4. 访问更新检查接口，确认返回版本、日志和平台包信息。
5. 打开 App 的“关于 -> 检查更新”做端到端验证。

## 已清理的旧方案

- 删除 GitHub / Gitee Release 同步 Action 和脚本。
- 删除 Cloudflare Worker / R2 更新后端。
- 当前更新服务不再以第三方 Release 托管作为版本信息来源。
