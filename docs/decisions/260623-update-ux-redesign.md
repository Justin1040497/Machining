# 260623 更新提示交互重构方案

## 状态

有效。已在 v1.2.1 开发期落地为工作台顶部 L1 状态胶囊、L2 轻量更新通知弹窗和 L3 完整版本日志页。

## 背景

当前更新提示存在三个入口重复展示同一信息、信息密度过高的问题：

- `UpdateReleaseNotesDialog`（720×520 modal）—— 工作台右上角点击 / 通知中心点击
- `ReleaseNotesPage`（全屏侧边栏 + markdown）—— 设置页"版本日志"按钮 / 弹窗"查看更多"
- 通知中心 —— 同样的 markdown 摘要

用户每次接触更新提示都被全量 markdown 淹没，而核心问题"有没有新版本、要不要更新"被淹没在文档中。

## 决策

将更新提示按信息密度分三层，入口收敛为单一弹窗。

### 层级结构

| 层级 | 形态 | 内容 | 触发方式 |
|------|------|------|----------|
| L1 轻提示 | 工作台右上角胶囊 | 版本号 + 状态 + `›` | 始终可见（有更新时） |
| L2 通知弹窗 | 380×320 modal | 版本号 + 摘要 + 操作按钮 | 点击 L1 / 开机自启 / 设置页检查 |
| L3 版本日志页 | 全屏页（保留现状） | 完整 markdown + 多版本浏览 | 从 L2「查看完整日志」或历史版本通知进入 |

### 入口变化对照

| 入口 | 现状 | 新方案 |
|------|------|--------|
| 工作台右上角 | 32×32 图标按钮，点击弹 720×520 modal | 胶囊轻提示 + `›`，点击弹 L2 通知弹窗 |
| 设置页「检查更新」 | 检查后 push 到 ReleaseNotesPage | 保留按钮；有更新→弹 L2，无更新→轻提示「已是最新」 |
| 设置页「版本日志」按钮 | 独立按钮，push 到 ReleaseNotesPage | **删除** |
| 通知中心更新通知 | 弹 `UpdateReleaseNotesDialog.history` | 当前版本弹 L2；历史版本直接进入 L3 |
| 工作台弹窗「查看更多」 | pop 当前弹窗 + push 日志页 | 弹窗内「查看完整日志」按钮 → push 日志页 |
| 版本日志页 | 多入口（设置 / 弹窗 / 通知） | **唯一入口**：L2 弹窗「查看完整日志」按钮 |

### L1 轻提示设计

改造 `_UpdateTopBarButton`（`top_bar.dart`）为胶囊形态：

```
┌─────────────────────┐
│ ● 新版本 v1.2.2  › │
└─────────────────────┘
```

状态文案：

| AppUpdateStatus | 轻提示文案 | 附带元素 |
|-----------------|-----------|----------|
| available | `新版本 vX.X.X ›` | 左侧小圆点 |
| downloading | `下载中 45% ›` | 左侧迷你进度环 |
| paused | `已暂停 45% ›` | 左侧小圆点（灰色） |
| downloaded | `已就绪 ›` | 左侧小圆点（绿色） |
| failed | `更新失败 ›` | 左侧小圆点（红色） |

- 显示条件不变：`updateState.isActive == true`
- 点击行为：打开 L2 通知弹窗

### L2 通知弹窗设计

新组件 `UpdateNoticeDialog`，替代 `UpdateReleaseNotesDialog`。

**尺寸**：约 380×320（对比现状 720×520，缩小 70%）

**内容结构**（available 状态）：

```
┌──────────────────────────────────┐
│ ↓  发现新版本                     │
│    2026-06-23 发布                 │
│                                   │
│ v1.2.2  从 v1.2.1 升级            │
│                                   │
│ 更新体验优化，修复若干问题         │
│ 新增批量导出预设管理               │
│                                   │
│ 安装包 128 MB · Windows x64       │
│ ───────────────────────────────── │
│ [立即更新] [下次再说] [查看完整日志]│
└──────────────────────────────────┘
```

**按钮按状态变化**：

| 状态 | 主按钮 | 次按钮 | 第三按钮 |
|------|--------|--------|----------|
| available | 立即更新 | 下次再说 | 查看完整日志 |
| downloading | 暂停下载 | 后台下载 | — |
| paused | 继续下载 | 后台下载 | — |
| downloaded | 重启更新 / 打开 DMG | 后台隐藏 | — |
| failed | 重试 | 后台隐藏 | — |

**按钮行为**：

- **立即更新**：调用 `startOrResumeDownload()`，弹窗切换到 downloading 状态（不关闭）
- **下次再说**：关闭弹窗 + 记录 snooze（见下文）
- **查看完整日志**：关闭 L2 后进入 `/settings/release-notes?version=<version>&from=<source>`
- **暂停下载**：调用 `pauseDownload()`，弹窗切换到 paused 状态
- **后台下载 / 后台隐藏**：关闭弹窗，下载/安装状态由 L1 轻提示持续展示
- **重启更新 / 打开 DMG**：调用 `installDownloadedUpdate()`（含任务检查弹窗）

### snooze 机制

用户点击「下次再说」后：

1. 将当前 `release.version` 写入本地 snooze 记录（`update-snoozed-version` 文件）
2. 开机自启时检查更新：有更新但 `version == snoozedVersion` → **不自动弹窗**，只显示 L1 轻提示
3. 服务端发布新版本（version 变化）→ 自动取消 snooze，开机恢复弹窗
4. snooze **不影响**手动入口：用户点 L1 轻提示 / 设置页「检查更新」仍会弹 L2
5. snooze 不需要时间维度（不搞"7天后再提醒"），版本维度足够——同一版本用户已经决定不看，不该反复打扰

### 开机自启策略

```
app 启动
  → 自动检查更新（现状不变）
  → 有更新？
      → 是 → version == snoozedVersion？
          → 是 → 只显示 L1，不弹 L2
          → 否 → 延迟 2 秒后自动弹 L2（等 UI 渲染完）
      → 否 → 不显示 L1，不弹 L2
```

延迟 2 秒的原因：避免 app 刚启动就弹窗打断用户，给用户先看到工作台的时间。

### 设置页变化

`settings_sections.dart` 的「关于」区：

**现状**：
```
更新
├── [检查更新] [版本日志]
```

**新方案**：
```
更新
└── [检查更新]
```

- 删除「版本日志」按钮（`_MaintenanceButton(label: '版本日志', ...)`）
- 「检查更新」行为变更：`checkUpdateAndOpenReleaseNotes()` → `checkUpdateAndShowNotice()`
  - 检查中：按钮显示「检查中」，禁用
  - 有更新：弹 L2 通知弹窗
  - 无更新：轻提示「已是最新版本」（不用弹窗，用现有 notification system）
  - 检查失败：轻提示错误消息

### 版本日志页调整

`ReleaseNotesPage` 保留，但调整：

1. **入口收敛**：主要入口是 L2 弹窗「查看完整日志」按钮；历史版本通知可直接进入 L3
2. **返回逻辑**：`from` 参数保留来源页面（工作台 / 设置页），返回到真实来源
3. **功能不变**：左侧版本列表 + 右侧 markdown 的布局保留，给需要查看历史的用户
4. **删除 history 弹窗**：当前更新通知点击弹 L2；历史版本通知直接进入 L3 版本日志页

### 要删除 / 替换的组件

| 组件 | 处理 |
|------|------|
| `UpdateReleaseNotesDialog` | **替换**为 `UpdateNoticeDialog`（尺寸/内容全面重写） |
| `UpdateReleaseNotesDialog.history` 构造 | **删除** |
| 设置页 `_MaintenanceButton(label: '版本日志')` | **删除** |
| `checkUpdateAndOpenReleaseNotes()` | **改写**为 `checkUpdateAndShowNotice()` |
| `openUpdateLogFromNotification()` 中的 history dialog 分支 | **改写**为弹 L2 |
| `_UpdateTopBarButton` | **改造**为胶囊轻提示样式 |

### 数据模型变化

新增 snooze 状态持久化：

```dart
// 新增：application/services/app_update/app_update_snooze_store.dart
abstract class AppUpdateSnoozeStore {
  Future<String?> loadSnoozedVersion();
  Future<void> saveSnoozedVersion(String version);
  Future<void> clearSnoozedVersion();
}

// 新增：infrastructure/services/app_update/local_app_update_snooze_store.dart
// 存储到 applicationSupportDirectory/update-snoozed-version
```

`AppUpdateState` 无需变化——snooze 是独立的持久化状态，不混入 update state。

`AppUpdateNotifier` 与 provider 新增：
- `appUpdatePendingAutoNoticeProvider` —— 自动检查发现未 snooze 更新时置为 `true`，由工作台监听后延迟弹出 L2
- `consumeAutoNotice()` —— UI 展示 L2 后消费 pending 标记
- `snoozeCurrentVersion()` —— 记录当前版本为 snoozed，并清除 pending 标记

## 已确认问题

1. **mandatory 更新**：`release.mandatory == true` 时隐藏「下次再说」，弹窗不可点击遮罩关闭，只能执行更新操作或查看完整日志。

2. **L2 弹窗是否阻断**：非 mandatory 更新可点击外部关闭；mandatory 例外，阻断关闭。

3. **下载中弹窗关闭后**：下载不依赖弹窗存活，后台下载 / 后台隐藏只关闭弹窗，状态继续由 L1 胶囊承接。

4. **通知中心历史版本**：历史版本通知直接进入 L3 日志页，因为旧版本没有「立即更新」意义。

## 影响范围

### 落地改动范围

- `lib/features/workbench/pages/workbench_page/layout/top_bar.dart` — 改造 `_UpdateTopBarButton`
- `lib/app/presentation/widgets/update_notice_dialog.dart` — 新增 L2 更新通知弹窗
- `lib/features/workbench/pages/workbench_page/dialogs/update_release_notes_dialog.dart` — 删除旧全量 markdown 弹窗
- `lib/features/workbench/pages/workbench_page.dart` — `showCurrentUpdateDialog()` / `openUpdateLogFromNotification()` 改写
- `lib/features/settings/pages/app_settings_page.dart` — `checkUpdateAndOpenReleaseNotes()` 改写
- `lib/features/settings/sections/settings_sections.dart` — 删除「版本日志」按钮
- `lib/app/providers/app_update_provider.dart` — 新增 snooze 相关逻辑
- 新增 `lib/application/services/app_update/app_update_snooze_store.dart`
- 新增 `lib/infrastructure/services/app_update/local_app_update_snooze_store.dart`

### 测试

- `test/app_update_provider_test.dart` — 新增 snooze 场景测试

## 关联

- `docs/decisions/260623-update-system-review.md` — 更新系统全面审查报告
- `docs/decisions/260616-self-hosted-update-client-server-flow.md` — 更新客户端入口决策
- `docs/decisions/260620-managed-update-and-sparkle.md` — 托管更新配置决策
