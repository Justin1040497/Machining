# 更新提示交互重构 — 实施概览

## 完成内容

将更新提示从"全量 markdown modal"重构为三层信息密度架构，收敛入口，新增 snooze 机制和开机自启弹窗。

## 改动清单

### 新增（3 个文件）
| 文件 | 作用 |
|------|------|
| `lib/application/services/app_update/app_update_snooze_store.dart` | snooze 持久化端口 |
| `lib/infrastructure/services/app_update/local_app_update_snooze_store.dart` | 本地文件实现 |
| `lib/app/presentation/widgets/update_notice_dialog.dart` | L2 通知弹窗（380×300） |

### 删除（1 个文件）
| 文件 | 原因 |
|------|------|
| `lib/features/workbench/pages/workbench_page/dialogs/update_release_notes_dialog.dart` | 被 UpdateNoticeDialog 替代 |

### 修改（8 个文件）
| 文件 | 改动 |
|------|------|
| `lib/app/providers/app_update_provider.dart` | +snooze provider / +AutoNoticeController / +snoozeCurrentVersion / +consumeAutoNotice / checkForUpdate 加入 snooze 同步与 auto-notice 设置 |
| `lib/features/workbench/pages/workbench_page/layout/top_bar.dart` | _UpdateTopBarButton 从图标改为胶囊轻提示 |
| `lib/features/workbench/pages/workbench_page.dart` | showCurrentUpdateDialog→showUpdateNotice / 历史版本直接进 L3 / +_autoNoticeSubscription 开机自启监听 |
| `lib/features/settings/pages/app_settings_page.dart` | checkUpdateAndOpenReleaseNotes→checkUpdateAndShowNotice / 删除 onOpenReleaseNotes |
| `lib/features/settings/sections/settings_sections.dart` | 删除「版本日志」按钮 |
| `lib/app/library.dart` | +export update_notice_dialog |
| `lib/application/library.dart` | +export app_update_snooze_store |
| `lib/infrastructure/library.dart` | +export local_app_update_snooze_store |
| `test/app_update_provider_test.dart` | +FakeAppUpdateSnoozeStore / +override |

## 关键设计决策

1. **snooze 用版本维度**：同版本不再自动弹，新版本自动恢复提醒
2. **开机自启延迟 2 秒**：等 UI 渲染完再弹，不打断用户看工作台
3. **mandatory 强制**：PopScope 不可关闭 + barrierDismissible false + 隐藏「下次再说」
4. **历史版本直接进 L3**：通知中心点击旧版本通知 → 直接进日志页，不弹 L2
5. **NotifierProvider 替代 StateProvider**：项目 Riverpod 约定不用 StateProvider

## 入口变化

| 入口 | 变化 |
|------|------|
| 工作台右上角 | 图标 → 胶囊轻提示（版本号+状态+›），点击弹 L2 |
| 设置页「检查更新」 | 保留；有更新→弹 L2，无更新→轻提示 |
| 设置页「版本日志」按钮 | **删除** |
| 通知中心当前版本 | 弹 L2 |
| 通知中心历史版本 | 直接进 L3 日志页 |
| 版本日志页 | 唯一入口：L2 弹窗「查看完整日志」 |

## 待办

- 运行 `flutter analyze` 和 `flutter test` 验证（本次因 sandbox 限制未执行）
- 视觉走查 UpdateNoticeDialog 在各状态下的表现
