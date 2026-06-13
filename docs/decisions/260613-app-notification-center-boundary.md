# 260613 应用通知中心边界

## 状态

有效。

## 背景

工作台、设置页、FFmpeg 队列和后续自托管更新都会产生用户需要回看的事件。如果继续让各页面各自弹出临时提示，保存进行中离开页面、后台任务完成、失败原因回看和通知中心扩展都会变得分散且脆弱。

## 决策

应用通知统一由 application 层的 `AppNotificationManager` 记录：

- 业务事件先写入 `AppNotificationRepository`，再交给根级 `AppNotificationHost` 展示临时通知。
- 通知中心只读取持久化通知历史，不从工作台或设置页局部状态拼装列表。
- 根级临时浮层只承担即时反馈；通知中心承担完整历史、已读、清扫和动作入口。
- 通知类型使用 `general`、`settings`、`task` 等可扩展枚举；类型特有动作通过 `payload_json` 和 `NotificationCenterActionResolver` 解析。
- 任务完成 / 失败通知由 FFmpeg 队列收尾直接发布，不依赖工作台页面仍然可见。
- 设置保存通过 `AppSettingsSaveCoordinator` 进入通知管理器，保存进行中离开设置页后仍由全局通知反馈结果。
- 工作台通知角标只是展示偏好，隐藏角标不改变通知未读状态、通知中心入口或持久化历史。

## 影响

- 新通知类型，例如后续版本更新通知，应优先新增通知 kind、payload 和动作解析，而不是改写通知中心主体。
- UI 页面不再直接负责跨页面通知结果；页面只负责触发业务动作和传递必要上下文。
- 临时通知、通知中心、任务完成音效都可以订阅同一通知事件，但不能反向影响任务状态或通知持久化语义。

## 关联事实

- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/test-plan.md`
