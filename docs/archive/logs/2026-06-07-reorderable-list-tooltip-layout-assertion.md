# ReorderableListView 拖拽 Tooltip 布局断言

## 问题

工作台任务列表接入 `ReorderableListView.builder` 后，拖拽任务项会触发 Flutter 布局断言：

```text
_RenderLayoutBuilder was mutated in _RenderLayoutBuilder.performLayout
```

报错堆栈指向任务列表布局：

```text
lib/features/workbench/pages/workbench_page/layout/task_list_card.dart
```

同时堆栈中出现 `_OverlayPortalElement.activate`，说明问题和拖拽期间 overlay 子树重挂载有关。

## 根因

这次问题不是 `oldIndex` / `newIndex` 算法错误。当前项目仍使用本地 Flutter SDK 暴露的 `onReorder`，索引偏移已由 `ReorderMediaTasksUseCase` 处理：

```dart
if (targetIndex > oldIndex) {
  targetIndex -= 1;
}
```

真实触发链路是：

1. `ReorderableListView` 拖拽时会把原列表项子树作为拖拽代理放入 overlay。
2. 任务列表项内部有多个 `Tooltip`。
3. Flutter `Tooltip` / `RawTooltip` 依赖 overlay 机制，内部会使用 `OverlayPortal.overlayChildLayoutBuilder`。
4. 拖拽代理重挂载 item 子树时，`Tooltip` 的 overlay portal 激活与 layout 阶段交叠，最终触发 `_RenderLayoutBuilder` mutation 断言。

## 修复

- `MediaTaskActionButton` / `MediaTaskIconButton` 增加 `tooltipsEnabled` 参数。
- `MediaTaskListTile` 增加 `tooltipsEnabled` 参数。
- 在 `TaskListCard` 的 `ReorderableListView` item 内传入 `tooltipsEnabled: false`。
- 任务文件名、操作按钮和拖拽手柄在关闭 tooltip 时使用 `Semantics(label: ...)` 保留无障碍说明。
- 保留 `ValueKey(task.id)` 作为稳定 item key。
- 保留现有 `onReorder`，继续由 use case 负责 `newIndex` 偏移修正和持久化排序。

## 验证

- 新增 widget 回归测试：拖拽手柄开始重排时不抛 layout 异常，并触发 reorder 回调。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `git diff --check`。

## 后续注意

在 `ReorderableListView` item 子树中，如果继续加入菜单、弹层、portal、tooltip 或其他会创建 overlay 的控件，需要优先确认拖拽代理重挂载时不会触发布局阶段 mutation。普通非拖拽上下文仍可以保留 tooltip。
