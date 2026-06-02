# 自托管更新服务

## 目标

FrameLean 的应用更新检查不再直接访问 GitHub / Gitee Releases，也不依赖 Cloudflare Workers / R2 作为更新源。

目标架构改为自有服务器托管：

```text
FrameLean 客户端
  -> 自有 Rust 更新服务
  -> 自有服务器上的安装包和更新元数据
```

服务端负责返回最新版本、更新说明、平台安装包地址和校验信息。后续实现时，更新接口需要加入请求鉴权，安装包下载地址需要使用短期有效的签名链接。

## 仓库布局建议

当前阶段先采用过渡布局：

```text
FrameLean/
  lib/                         当前 Flutter 客户端源码，暂不移动
  macos/
  windows/
  server/
    update-service/            Rust 自有更新服务，后续实现
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

后续 Rust 更新服务按下面方向实现，具体字段以服务端和客户端最终代码为准。

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

### 版本日志

```text
GET /api/v1/releases/{version}/notes
```

### 平台安装包

```text
GET /api/v1/releases/{version}/packages/{platform}
GET /api/v1/releases/{version}/packages/{platform}/download
```

## 发布顺序

1. 打包生成 macOS DMG 和 Windows 安装器。
2. 计算安装包 SHA-256。
3. 将安装包、日志和版本元数据发布到自有服务器。
4. 访问更新检查接口，确认返回版本、日志和平台包信息。
5. 打开 App 的“关于 -> 检查更新”做端到端验证。

## 已清理的旧方案

- 删除 GitHub / Gitee Release 同步 Action 和脚本。
- 删除 Cloudflare Worker / R2 更新后端。
- 当前更新服务不再以第三方 Release 托管作为版本信息来源。
