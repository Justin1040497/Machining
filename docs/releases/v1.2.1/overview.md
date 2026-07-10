# v1.2.1 版本概览

## 当前事实

`v1.2.1` 是更新体验、媒体处理可靠性、任务夹交互和桌面工作流集中收口的版本。客户端接入自动检查、L1 状态胶囊、L2 更新通知、L3 完整版本日志、同版本 snooze 和 GitHub / Gitee / 备用下载入口；服务端迁移到 RuoYi-Vue-Plus 5.X + plus-ui 5.X，并保留 package、COS、download ticket、Windows updater helper 与 Sparkle appcast 兼容能力。

当前公开发布以外部下载地址为默认。release 带任一外部地址时，客户端只展示日志和跳转入口，不直接下载或安装 EXE、DMG、ZIP。没有外部地址且服务端返回完整 package 元数据时，原自更新包链仍可使用，但 Admin 默认隐藏该入口，也不再把 Windows / macOS package 设为发布必填。

## 重要事实设计

| 文档 | 说明 |
| --- | --- |
| `self-hosted-update-client.md` | 更新检查、外部下载入口和保留 package 客户端能力 |
| `self-hosted-update-server.md` | RuoYi 更新服务、外部下载地址、Redis、PostgreSQL、可选 COS package 边界 |
| `admin-web-release-management.md` | Admin 登录、版本草稿、日志、下载地址、审计和隐藏 package 能力 |
| `docs/decisions/260710-external-download-default.md` | 外部下载地址优先的当前发布决策 |
| `docs/develop/architecture.md` | 图片输出验收、透明保留、输出 preflight 和任务夹工作台结构 |
| `docs/develop/data-model.md` | Drift schema 29、任务夹表、策略标签、通知策略、快捷键和关闭行为字段 |

## 当前发布边界

- 从旧版本检查更新后，应展示 L2 更新通知、完整版本日志和已登记的 GitHub / Gitee / 备用下载按钮；点击后由系统浏览器打开，不调用 download ticket。
- 发布 release 时，版本日志必填；没有 package 时至少需要一个合法的 HTTP(S) 外部下载地址。
- macOS Universal 2 DMG、Windows x64 当前用户安装器和可选便携 ZIP 仍是用户下载产物。canonical release 脚本继续要求更新地址与 Windows 签名配置完整，并生成 `*.update.json`。
- package 自更新链仅作为保留能力：Windows 可断点下载、SHA-256 + Ed25519 验签并启动 helper；macOS 可下载 DMG 到应用私有目录后手动安装；Sparkle 只在显式配置并具备签名时使用。
- RuoYi 服务端仍依赖 PostgreSQL 和 Redis。COS 是版本日志文件和可选 package 的存储能力；外部下载地址模式不要求把安装包上传 COS。

## 当前仍需验证

- 在真实部署环境发布包含版本日志与外部下载地址的 `v1.2.1`，验证 `/latest`、`/notes`、Redis latest cache 清理、审计记录和反代真实 IP。
- 在 macOS Universal 2 和 Windows x64 客户端验证 GitHub、Gitee、备用下载按钮与系统浏览器跳转。
- 在 GitHub Actions 生成真实 DMG、Windows 安装器和 ZIP，核对架构、运行时、法律资料、更新地址和 `*.update.json`。
- package 自更新、COS ticket、Windows helper、macOS 私有 DMG 缓存和 Sparkle appcast 不属于当前默认发布阻塞项；若重新启用，需要单独执行端到端验收。
- 显式手动指定图片输出格式时，当前无效输出会失败并提示原因；“首轮无效后询问是否允许改格式”尚未接入队列中的交互确认链。
