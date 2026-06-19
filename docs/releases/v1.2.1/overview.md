# v1.2.1 版本概览

## 当前事实

`v1.2.1` 是自托管更新能力进入主流程、媒体处理可靠性修复和任务夹交互重构并行推进的开发版本。它把客户端更新入口、下载状态、版本日志、Windows updater helper 和 server v1.0.0 更新服务接到同一条链路中，同时修复图片越压越大、透明素材错误输出和输出路径启动后才失败的问题，并让批量导入、任务夹设置、多选建夹、拖入任务夹和夹内执行进入持久化任务夹模型。

这个版本仍是 `No Release` 记录：代码和文档已经描述当前能力边界，但正式发布前仍需要在真实 Windows x64、macOS Universal 2、COS、Redis 和宝塔反代环境中完成端到端验收。

## 重要事实设计

| 文档 | 说明 |
| --- | --- |
| `self-hosted-update-client.md` | 客户端检查更新、通知、下载、日志和 Windows helper 边界 |
| `self-hosted-update-server.md` | Spring Boot 更新服务、Redis ticket、PostgreSQL 长期事实和 COS 分发边界 |
| `admin-web-release-management.md` | Admin Web 登录、版本草稿、分片上传、发布、审计和 IP 屏蔽边界 |
| `docs/develop/architecture.md` | 图片输出验收、透明保留、输出 preflight 和任务夹工作台结构 |
| `docs/develop/data-model.md` | Drift schema 25、任务夹表、任务 folder 字段和策略标签字段 |

## 当前仍需验证

- Windows x64 从旧版本检查更新、下载安装器、启动 `FrameLeanUpdaterHelper.exe`、静默覆盖安装并重启应用。
- macOS Universal 2 当前只承诺检查更新、查看日志和下载包；自动替换安装不属于本阶段完成范围。
- COS 私有桶、预签名上传 / 下载、Redis ticket TTL、latest cache 清理和反代真实 IP 在部署环境中一致工作。
- `ed25519Signature` 仍是协议字段，客户端下载后当前强校验是 SHA-256；包签名生成、验签公钥分发和失败恢复需要单独收口。
- `docs/develop/test-plan.md` 中的 v1.2.1 Windows / macOS 发布包验收仍需在正式发布环境执行。
- 任务夹交互已覆盖自动建夹、总列表折叠、夹级设置批量应用、左侧夹内任务浮层、多选建夹、顶层排序 / 入夹 hover freeze 和夹内排序。两层列表统一使用全应用 `FrameLeanReorderableListView`；夹内任务可拖到遮罩原地收起并追加到整个顶层混排列表尾部，失败时回滚。任务行不再显示蓝色选中边框。
- 显式手动指定图片输出格式时，当前无效输出会失败并提示原因；“首轮无效后询问是否允许改格式”尚未接入队列中的交互确认链。
