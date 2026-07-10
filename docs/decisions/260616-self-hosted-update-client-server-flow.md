# 260616 自托管更新客户端入口与服务端 Redis 边界

## 状态

部分被 `260710-external-download-default.md` 取代。L1 / L2 / L3 入口、通知去重和 Redis 长短期数据边界继续有效；直接 package 下载不再是当前默认发布动作。

## 背景

FrameLean 自托管更新需要同时满足低打扰、可回看、可继续、可安装和可自托管部署。只在弹窗中提示更新会显得廉价，也会破坏用户正在处理媒体任务的节奏；只在设置页展示又会让用户回到工作台后失去继续下载和查看日志的入口。

服务端需要支持多实例部署、短期下载授权和限流，但 release、package、发布状态和下载事件仍是长期事实，不应放进 Redis。

## 决策

- 客户端更新入口由三部分组成：设置页“关于”栏主按钮、通知中心单版本通知、工作台顶部持续下载入口。
- 每次打开应用自动静默检查一次；用户点击关于栏 `检查更新` 时手动检查一次，检查期间按钮禁用并显示 `检查中`。
- 发现新版本后，默认 release 在 L2 弹窗展示 GitHub、Gitee 或备用下载入口；只有没有外部地址且 package 元数据完整时，才进入 Windows `现在更新` 或 macOS `下载 DMG` 动作。通知中心 upsert 一条版本更新通知，工作台顶部持续显示更新入口。
- 通知中心一个版本只保留一条更新通知，使用 `app_notifications.dedupe_key = update:{platform}:{version}:{buildNumber}` 保证跨重启去重。
- 当前更新通知尾部展示版本日志和下载动作；当前版本通知点击打开轻量更新通知弹窗，历史版本通知直接进入完整版本日志页。
- 工作台顶部更新入口不直接下载，以 L1 状态胶囊展示新版本；点击打开 L2 更新通知弹窗。保留 package 路线仍可展示下载中、暂停、已就绪或失败状态和迷你进度。
- 保留 package 路线下载中，关于栏主按钮显示百分比并支持暂停 / 继续；下载完成后 Windows 可重启更新，macOS 可打开 DMG 所在位置。
- 保留 Windows package 安装前如果存在运行中、暂停中、等待中或分析中的任务，先确认并暂停任务，再交给独立 `FrameLeanUpdaterHelper.exe`。
- 服务端 Redis 只保存短期状态：下载 ticket、限流计数和 latest cache。长期 release / package / notes / download event 继续保存在 PostgreSQL。
- 服务端发布 release 前必须校验日志；没有 package 时至少需要一个外部下载地址。登记 package 时继续校验 size、SHA-256、签名和 COS object key；latest 查询允许按平台 package 或平台无关外部地址返回更新。

## 影响

- 通知中心动作从单 action 扩展为可多 action，但任务成功通知仍保留原有打开成果物行为。
- Drift schema 升级到 24，新增 `app_notifications.dedupe_key` 和唯一索引。
- 更新服务端部署必须提供 Redis；Docker Compose 同时启动 PostgreSQL 和 Redis。
- 当前默认由用户从外部页面下载安装；macOS 自动替换安装仍不在本阶段承诺范围内，Windows helper 只属于保留 package 路线。
- 260623 更新提示交互决策进一步细化了入口层级、snooze 语义和 mandatory 弹窗关闭规则。
- 260710 外部下载优先决策进一步调整了默认下载动作和服务端发布门禁。

## 关联事实

- `CONTEXT.md`
- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
