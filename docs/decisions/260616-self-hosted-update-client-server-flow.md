# 260616 自托管更新客户端入口与服务端 Redis 边界

## 状态

有效。

## 背景

FrameLean 自托管更新需要同时满足低打扰、可回看、可继续、可安装和可自托管部署。只在弹窗中提示更新会显得廉价，也会破坏用户正在处理媒体任务的节奏；只在设置页展示又会让用户回到工作台后失去继续下载和查看日志的入口。

服务端需要支持多实例部署、短期下载授权和限流，但 release、package、发布状态和下载事件仍是长期事实，不应放进 Redis。

## 决策

- 客户端更新入口由三部分组成：设置页“关于”栏主按钮、通知中心单版本通知、工作台顶部持续下载入口。
- 每次打开应用自动静默检查一次；用户点击关于栏 `检查更新` 时手动检查一次，检查期间按钮禁用并显示 `检查中`。
- 发现新版本后，关于栏按钮进入平台对应的下载动作：Windows 显示 `现在更新`，macOS 手动 DMG 路线显示 `下载 DMG`；通知中心 upsert 一条版本更新通知，工作台顶部在主题切换按钮左侧持续显示亮色下载入口。
- 通知中心一个版本只保留一条更新通知，使用 `app_notifications.dedupe_key = update:{platform}:{version}:{buildNumber}` 保证跨重启去重。
- 当前更新通知尾部展示 `前往` 和下载 icon：`前往` 打开版本日志弹窗，下载 icon 直接开始下载。
- 工作台顶部更新入口不直接下载，始终打开版本日志弹窗；下载中显示圆形进度。
- 下载中关于栏主按钮保持固定尺寸，内部显示百分比，点击暂停；暂停后点击继续；下载完成后 Windows 点击重启更新，macOS 点击打开 DMG 所在位置。
- 重启安装前如果存在运行中、暂停中、等待中或分析中的任务，先用项目风格弹窗告知重启会暂停任务，确认后暂停任务并交给 updater helper。
- Windows 自动安装阶段必须通过独立 `FrameLeanUpdaterHelper.exe` 运行安装器；主应用只负责下载、断点续传、SHA-256 校验和启动 helper。
- 服务端 Redis 只保存短期状态：下载 ticket、限流计数和 latest cache。长期 release / package / notes / download event 继续保存在 PostgreSQL。
- 服务端发布 release 前必须校验 notes、package、size、sha256、signature 和 COS object key；latest 查询必须按平台包可用性过滤。

## 影响

- 通知中心动作从单 action 扩展为可多 action，但任务成功通知仍保留原有打开成果物行为。
- Drift schema 升级到 24，新增 `app_notifications.dedupe_key` 和唯一索引。
- 更新服务端部署必须提供 Redis；Docker Compose 同时启动 PostgreSQL 和 Redis。
- macOS 自动替换安装仍不在本阶段承诺范围内；当前客户端会检查更新和展示日志，但自动安装边界优先服务 Windows x64。

## 关联事实

- `CONTEXT.md`
- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
