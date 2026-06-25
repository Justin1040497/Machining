# Feature Widget 可复用性分析报告

> 范围：`lib/features/` 目录下的 Widget 组件
> 目标：识别可单独拆分、跨 feature 复用的 Widget，给出提取优先级和落地路径

## 1. 执行摘要

FrameLean 的 `lib/features/` 下存在 **三类可复用性问题**：

| 问题类型 | 严重程度 | 涉及组件数 | 根因 |
|---------|---------|-----------|------|
| copy-paste 重复 | P0 | 6 | `WorkbenchDialogFrame` 系列与 `AppDialogFrame` 系列逐行复制 |
| part-of 锁定 | P1 | 10+ | settings widget 全部为 `part of` 私有类，无法跨 feature 引用 |
| 纯逻辑内嵌 | P2 | 3 | `MediaTaskListTile` 内嵌格式化函数，无法独立测试和复用 |

**核心判断**：项目已有 `lib/app/presentation/widgets/` 共享层（ConfigDropdown、PathField、AppDialogFrame 等），方向正确。但 features 层存在「该共享的没共享、已共享的被复制了一份」的失控迹象，建议在功能继续膨胀前做一轮收敛。

## 2. 当前架构现状

### 2.1 已有的共享层（健康）

`lib/app/presentation/widgets/` 下已有 10 个文件，覆盖：

| 组件 | 职责 | 复用情况 |
|------|------|---------|
| `AppDialogFrame` / `AppDialogTitle` / `AppDialogActionButton` | 对话框骨架 | settings 使用，workbench **未使用**（自己复制了一份） |
| `ConfigDropdown<T>` | 通用下拉选择 | settings + workbench config panels 均使用 |
| `ConfigCheckbox` | 通用复选框 | workbench config panels 使用，settings **未使用**（自己写了一份） |
| `PathField` | 路径输入 + 拖拽 | settings 使用 |
| `PercentageSliderPanel` | 百分比滑块 | workbench image config 使用 |
| `SidebarPageScaffold` | 侧边栏页面骨架 | settings 使用 |
| `FrameLeanReorderableListView` | 可重排列表 | workbench task list 使用 |
| `NotificationCenterPanel` | 通知中心面板 | 全局使用 |

### 2.2 问题一：Dialog 框架 copy-paste 重复（P0）

**最严重的重复**。以下两组组件几乎逐行相同：

```
lib/app/presentation/widgets/app_dialog_frame.dart
  ├── AppDialogFrame          ← Dialog 骨架，maxWidth/padding/圆角10
  ├── AppDialogTitle          ← 18px w600 标题
  └── AppDialogActionButton   ← 28px 高，前景色按背景色推导

lib/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart
  ├── WorkbenchDialogFrame          ← 完全相同
  ├── WorkbenchDialogTitle          ← 完全相同
  ├── WorkbenchDialogBodyText       ← workbench 独有，可合并
  ├── WorkbenchDialogBackHeader     ← workbench 独有，可合并
  ├── WorkbenchDialogActions        ← workbench 独有，可合并
  └── WorkbenchDialogActionButton   ← _resolveForegroundColor 逻辑完全相同
```

**影响**：改一个忘了改另一个 → 视觉不一致。目前两份代码的 `_resolveForegroundColor` 已经是完全一样的 if-else 链。

### 2.3 问题二：Confirm 弹窗模式重复（P0）

4 个确认弹窗 + settings 里 1 个，全部遵循相同结构：

```
DialogFrame
  ├── DialogTitle
  ├── DialogBodyText (可选)
  └── Row[ ActionButton(取消) + ActionButton(确认) ]
```

涉及文件：
- `features/workbench/.../dialogs/confirm/clear_tasks_dialog.dart`
- `features/workbench/.../dialogs/confirm/compression_confirmation_dialog.dart`
- `features/workbench/.../dialogs/confirm/import_failure_dialog.dart`
- `features/workbench/.../dialogs/confirm/restart_unelevated_dialog.dart`
- `features/settings/widgets/settings_about_widgets.dart` → `_ConfirmMaintenanceDialog`

### 2.4 问题三：Settings widget 被 part-of 锁定（P1）

`features/settings/widgets/` 下三个文件全部以 `part of '../pages/app_settings_page.dart';` 开头：

- `settings_page_widgets.dart` — `_SettingsLoading`、`_SettingsLoadError`、`_SettingsContent`、`_SettingsForm`、`_SettingsSidebar`、`_SidebarGroup`、`_SidebarItem`
- `settings_form_widgets.dart` — `_SectionActions`、`_SettingsDropdown`、`_SettingsCheckbox`、`_TwoColumnFields`、`_FormFieldLabel`、`_NotificationPolicyTable`、`_ShortcutBindingRow`
- `settings_about_widgets.dart` — `_AboutTextBlock`、`_AboutIconLinks`、`_AboutActionCluster`、`_MaintenanceButton`、`_ConfirmMaintenanceDialog`

**问题**：这些是私有类（`_` 开头），外部 feature 无法 import。其中多个组件是通用 UI 原语，不应绑定在 settings 页面内。

**特别重复**：`_SettingsCheckbox` 与已有的 `ConfigCheckbox` 功能完全相同（都是 InkWell + Checkbox + Label），只是尺寸参数略不同。

### 2.5 问题四：纯逻辑内嵌在 Widget 中（P2）

`MediaTaskListTile`（`features/workbench/widgets/media_task_list/media_task_list_tile.dart`）内嵌了三个纯函数：

```dart
String _formatBytes(int? bytes) { ... }        // 字节格式化，通用
String _formatPercent(double value) { ... }     // 百分比格式化，通用
String policyTagLabel(MediaTaskPolicyTag tag) { ... }  // 策略标签，领域相关
```

这些函数不依赖 BuildContext，是纯逻辑，但锁在 Widget 文件里无法被其他列表项（如 `TaskFolderListTile`）复用，也无法单独测试。

## 3. 可提取组件清单（按优先级）

### P0：消除 copy-paste 重复（立即做）

| # | 提取项 | 来源 | 目标位置 | 工作量 |
|---|-------|------|---------|-------|
| 1 | Dialog 框架合并 | `WorkbenchDialogFrame/Title/ActionButton` | 删除 workbench 版，全部改用 `AppDialogFrame` 系列 | 小 |
| 2 | `ConfirmDialog` 模板 | 5 个确认弹窗 | `app/presentation/widgets/dialogs/confirm_dialog.dart` | 中 |
| 3 | Checkbox 统一 | `_SettingsCheckbox` | 删除，settings 改用 `ConfigCheckbox` | 小 |

**ConfirmDialog 模板设计**：

```dart
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '取消',
    this.confirmWidth = 75,
    this.singleAction = false,
  });
  // 返回 bool：true = 确认，false = 取消
}
```

### P1：从 part-of 释放通用布局组件（短期做）

| # | 提取项 | 来源（私有类） | 目标位置 | 通用性 |
|---|-------|--------------|---------|-------|
| 4 | `FormTwoColumnLayout` | `_TwoColumnFields` | `app/presentation/widgets/form_controls/` | 高 — 任何双列表单 |
| 5 | `FormFieldLabel` | `_FormFieldLabel` | `app/presentation/widgets/form_controls/` | 高 — 任何表单 |
| 6 | `SidebarNavGroup` + `SidebarNavItem` | `_SidebarGroup` / `_SidebarItem` | `app/presentation/widgets/navigation/` | 中 — 侧边栏导航 |
| 7 | `FormSaveCancelActions` | `_SectionActions` | `app/presentation/widgets/form_controls/` | 高 — 任何表单页 |
| 8 | `AsyncStateView` | `_SettingsLoading` / `_SettingsLoadError` | `app/presentation/widgets/feedback/` | 高 — 任何 AsyncValue 页面 |

**提取方式**：将 `part of` 改为独立文件 + `export`，类名去掉 `_` 前缀变为公开。settings 页面改为 import 使用。

### P2：从 Widget 剥离纯逻辑函数（机会改善）

| # | 提取项 | 来源 | 目标位置 | 理由 |
|---|-------|------|---------|------|
| 9 | `formatBytes(int?)` | `MediaTaskListTile._formatBytes` | `app/presentation/utils/formatters.dart` | 通用，TaskFolderListTile 也需要 |
| 10 | `formatPercent(double)` | `MediaTaskListTile._formatPercent` | `app/presentation/utils/formatters.dart` | 通用 |
| 11 | `policyTagLabel()` | `MediaTaskListTile.policyTagLabel` | `app/presentation/domain_labels.dart` | 领域标签，应与其他 domain label 统一 |

## 4. 建议的目标目录结构

```
lib/app/presentation/widgets/
├── dialogs/
│   ├── app_dialog_frame.dart          [已有] 合并 WorkbenchDialogFrame
│   ├── app_dialog_action_button.dart  [已有] 合并 WorkbenchDialogActionButton
│   └── confirm_dialog.dart            [新增] 模板化确认弹窗
├── form_controls/
│   ├── config_dropdown.dart           [已有]
│   ├── config_checkbox.dart           [已有] _SettingsCheckbox 删除后统一用此
│   ├── path_field.dart                [已有]
│   ├── form_field_label.dart          [新增] ← _FormFieldLabel
│   ├── form_two_column_layout.dart    [新增] ← _TwoColumnFields
│   └── form_save_cancel_actions.dart  [新增] ← _SectionActions
├── navigation/
│   ├── sidebar_page_scaffold.dart     [移动] 从 widgets/ 移入
│   └── sidebar_nav_group.dart         [新增] ← _SidebarGroup/_SidebarItem
├── feedback/
│   └── async_state_view.dart          [新增] ← _SettingsLoading/_SettingsLoadError
├── reorderable/                       [已有]
├── percentage_slider_panel.dart       [已有]
├── notification_center_panel.dart     [已有]
└── update_restart_warning_dialog.dart [已有]

lib/app/presentation/
├── utils/
│   └── formatters.dart                [新增] ← formatBytes, formatPercent
├── domain_labels.dart                 [已有] 合并 policyTagLabel
└── ...
```

## 5. 重构路径

### 阶段一：P0 重复消除（1-2 天）

1. 全局搜索 `WorkbenchDialogFrame`，替换为 `AppDialogFrame`
2. 将 `WorkbenchDialogBodyText`、`WorkbenchDialogBackHeader`、`WorkbenchDialogActions` 移入 `app_dialog_frame.dart`
3. 删除 `workbench_dialog_widgets.dart`
4. 创建 `ConfirmDialog`，逐个替换 5 个确认弹窗
5. settings 中 `_SettingsCheckbox` 替换为 `ConfigCheckbox`
6. `flutter analyze` + 运行现有测试

### 阶段二：P1 释放锁定（2-3 天）

1. 将 settings 的三个 `part of` 文件改为独立文件
2. 逐个提取通用组件到 `app/presentation/widgets/` 对应子目录
3. 类名去 `_`，settings 页面改 import
4. 为每个新组件补充 widget test

### 阶段三：P2 逻辑剥离（0.5 天）

1. 提取 `formatBytes` / `formatPercent` 到 `utils/formatters.dart`
2. 提取 `policyTagLabel` 到 `domain_labels.dart`
3. `MediaTaskListTile` 和 `TaskFolderListTile` 改为调用共享函数
4. 补充单元测试

## 6. 注意事项

- **不急于拆分 feature 专属组件**：`MediaTaskListTile`、`TaskFolderListTile`、`MediaTaskStatusBadge`、config panels 等是 workbench 专属的领域组件，当前单 feature 使用，暂不需要上提。等第二个 feature 需要类似列表时再提取。
- **保留 `part of` 的合理场景**：如果一个 widget 只在一个页面内使用且不会复用，`part of` 可以减少文件数量。判断标准是「是否有第二个消费者」。
- **ConfigDropdown 的 API 已较成熟**：它通过 `labelFontSize`、`valueFontSize`、`showLabel`、`showTrailingText` 等参数适配了 settings 和 workbench 两种场景，是好的抽象范本。新提取的组件应参考这种参数化方式。
- **每次提取后必须跑测试**：`docs/develop/workflow.md` 中定义了 Dart/Flutter 变更的检查命令，提取重构属于行为不变的重构，测试必须全绿。
