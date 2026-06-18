# v1.2.1 版本概览

## 当前事实

`v1.2.1` 是自托管更新能力进入主流程的开发版本。它把客户端更新入口、下载状态、版本日志、Windows updater helper 和 server v1.0.0 更新服务接到同一条链路中，同时为后续官网分发和运维审计准备 Admin Web。

这个版本仍是 `No Release` 记录：代码和文档已经描述当前能力边界，但正式发布前仍需要在真实 Windows x64、macOS Universal 2、COS、Redis 和宝塔反代环境中完成端到端验收。

## 重要事实设计

| 文档 | 说明 |
| --- | --- |
| `self-hosted-update-client.md` | 客户端检查更新、通知、下载、日志和 Windows helper 边界 |
| `self-hosted-update-server.md` | Spring Boot 更新服务、Redis ticket、PostgreSQL 长期事实和 COS 分发边界 |
| `admin-web-release-management.md` | Admin Web 登录、版本草稿、分片上传、发布、审计和 IP 屏蔽边界 |

## 当前仍需验证

- Windows x64 从旧版本检查更新、下载安装器、启动 `FrameLeanUpdaterHelper.exe`、静默覆盖安装并重启应用。
- macOS Universal 2 当前只承诺检查更新、查看日志和下载包；自动替换安装不属于本阶段完成范围。
- COS 私有桶、预签名上传 / 下载、Redis ticket TTL、latest cache 清理和反代真实 IP 在部署环境中一致工作。
- `ed25519Signature` 仍是协议字段，客户端下载后当前强校验是 SHA-256；包签名生成、验签公钥分发和失败恢复需要单独收口。
- `docs/develop/test-plan.md` 中的 v1.2.1 Windows / macOS 发布包验收仍需在正式发布环境执行。

