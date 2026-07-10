# P0 执行计划：Dialog 组件统一与 ConfirmDialog 模板化

## 状态
Proposed

## 背景

`lib/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart` 与 `lib/app/presentation/widgets/app_dialog_frame.dart` 存在 106 行逐行重复代码（Frame / Title / ActionButton 三个组件完全相同）。此外，4 个 confirm 弹窗中有 3 个骨架完全一致，可模板化消除重复。

## 决策

- **决策点 1 → 方案 A**：扩展 `app_dialog_frame.dart`，将 Workbench 独有的 3 个组件（BodyText / BackHeader / Actions）迁入并重命名为 `AppDialog*`，删除 `workbench_dialog_widgets.dart`。
- **决策点 2 → 方案 A**：新建 `ConfirmDialog` 极简模板，覆盖 3 个标准 confirm 弹窗。`import_failure_dialog` 因有自定义失败列表，保留独立组件。

## 组件 API 设计

### 1. 扩展后的 app_dialog_frame.dart（6 个组件）

```dart
// --- 已有组件（保持不变）---
class AppDialogFrame { child, maxWidth=410, padding }
class AppDialogTitle { title }
class AppDialogActionButton { label, backgroundColor, onPressed?, width=75 }

// --- 新增组件 ---

/// 弹窗正文文字
class AppDialogBodyText {
  final String text;
  final double fontSize;  // 默认 13
}

/// 带返回键的标题栏 — 用于二级页面型弹窗
class AppDialogBackHeader {
  final String title;
  final VoidCallback onClose;
  final Widget? trailing;  // 右侧 slot（状态徽章 / 操作按钮）
  // icon 直接用 Icons.keyboard_arrow_left_rounded，不依赖 WorkbenchIcons
}

/// 取消/保存按钮组 — 默认契约：左 leading + 右两按钮
class AppDialogActions {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Widget? leading;           // 左侧 slot（如状态徽章）
  final String cancelLabel;        // 默认 '取消'
  final String saveLabel;          // 默认 '保存'
}
```

### 2. 新建 confirm_dialog.dart

```dart
/// 二次确认弹窗模板
/// 契约：pop(false) = 取消，pop(true) = 确认
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    this.body,                    // 可选正文
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.confirmWidth = 75,       // 兼容 compression 的 96
    this.maxWidth = 410,
  });

  /// 便捷调用入口，返回 true=确认 / false=取消
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? body,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    double confirmWidth = 75,
    double maxWidth = 410,
  });
}
```

## 执行步骤

### Step 1：扩展 app_dialog_frame.dart
- 在现有文件末尾新增 `AppDialogBodyText` / `AppDialogBackHeader` / `AppDialogActions`
- `AppDialogBackHeader` 的返回 icon 直接用 `Icons.keyboard_arrow_left_rounded`
- 预计新增 ~107 行

### Step 2：新建 confirm_dialog.dart
- 路径：`lib/app/presentation/widgets/confirm_dialog.dart`
- 实现 `ConfirmDialog` widget + 静态 `show()` 方法
- 内部组合 `AppDialogFrame` + `AppDialogTitle` + `AppDialogBodyText` + `AppDialogActionButton`
- 预计 ~70 行

### Step 3：迁移 8 个调用文件

| 文件 | 改动 |
|------|------|
| `confirm/clear_tasks_dialog.dart` | **删除整个文件**，调用方改用 `ConfirmDialog.show()` |
| `confirm/restart_unelevated_dialog.dart` | **删除整个文件**，调用方改用 `ConfirmDialog.show()` |
| `confirm/compression_confirmation_dialog.dart` | **删除整个文件**，调用方改用 `ConfirmDialog.show()` |
| `confirm/import_failure_dialog.dart` | 保留，内部 `WorkbenchDialog*` → `AppDialog*` |
| `task/task_config_dialog_template.dart` | `WorkbenchDialogBackHeader` → `AppDialogBackHeader`，`WorkbenchDialogActions` → `AppDialogActions` |
| `task/task_log_dialog.dart` | `WorkbenchDialogFrame` → `AppDialogFrame`，`WorkbenchDialogBackHeader` → `AppDialogBackHeader`，`WorkbenchDialogActionButton` → `AppDialogActionButton` |
| `task/task_rename_dialog.dart` | `WorkbenchDialog*` → `AppDialog*` |
| `update_release_notes_dialog.dart` | `WorkbenchDialog*` → `AppDialog*` |

**注意**：删除 3 个 confirm 弹窗文件前，需先查找其调用方（`showDialog<ClearTasksDialog>()` 等），改为 `ConfirmDialog.show()` 调用。

### Step 4：删除 workbench_dialog_widgets.dart
- 确认无残留引用后删除
- 预期 `flutter analyze` 无 import 错误

### Step 5：更新测试
- `test/workbench_dialog_style_test.dart` — 引用从 `WorkbenchDialog*` 改为 `AppDialog*`
- `test/widget_test.dart` — 检查是否有 WorkbenchDialog 引用

### Step 6：验证
```bash
flutter analyze
flutter test
```

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 删除 confirm 弹窗文件后调用方断裂 | Step 3 先迁移调用方，再删除文件；删除前 `grep` 确认无引用 |
| `AppDialogBackHeader` 视觉与原 `WorkbenchDialogBackHeader` 不一致 | icon 都是 `Icons.keyboard_arrow_left_rounded`，颜色/尺寸完全照搬原代码 |
| `task_config_dialog_template` 用 Stack+Positioned 自建布局，不走 Frame | 不强制套 Frame，只替换它引用的 BackHeader / Actions 组件 |
| 测试快照可能变化 | Step 5 同步更新测试，运行 `flutter test` 验证 |

## 预期收益

| 指标 | 改动前 | 改动后 |
|------|--------|--------|
| Dialog 组件定义文件数 | 2 | 1 (+ confirm_dialog) |
| 重复代码行数 | 106 行 | 0 |
| 3 个 confirm 弹窗总行数 | ~130 行 | ~15 行调用代码 |
| 新增 confirm 弹窗成本 | 复制粘贴 ~45 行 | 一行 `ConfirmDialog.show()` |

## 后续

P0 完成后，可继续推进 P1（settings widget 解锁）和 P2（纯逻辑提取）。
