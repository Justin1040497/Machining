# 应用设置保存后未立即更新已有任务配置

## 日期

2026-05-28

## 现象

用户在设置弹窗中修改默认压缩配置、默认导出地址、默认导出文件名模板后保存，修改只对新导入的任务生效，已有任务列表中的任务仍然使用旧的默认配置。

## 根因

`saveAppSettings` 在 `workbench_page.dart` 中只将设置持久化到数据库并刷新 FFmpeg 运行时，没有触发现有任务配置的更新。

任务的初始配置仅在 `ImportMediaTaskUseCase` 被调用时通过 `buildInitialTaskConfigFromSettings` 生成一次，之后与设置脱钩。

## 修复

在 `MediaTaskListNotifier` 中新增 `applySettingsToExistingTasks(AppSettings)` 方法：

- 遍历所有当前任务
- 对状态为 `pending`、`failed`、`cancelled` 的任务，根据新设置重建 `VideoTaskConfig`
- 逐个保存更新后的任务并刷新 state

在 `saveAppSettings` 末尾调用该方法，使设置保存时立即将新的默认配置应用到所有待处理任务。

## 涉及文件

- `lib/features/workbench/providers/media_task_notifier.dart` — 新增 `applySettingsToExistingTasks` 方法
- `lib/features/workbench/pages/workbench_page.dart` — `saveAppSettings` 末尾调用新方法

## 验证

- 通过 `dart format --set-exit-if-changed`
- 通过 `flutter analyze`
- 通过 `flutter test`