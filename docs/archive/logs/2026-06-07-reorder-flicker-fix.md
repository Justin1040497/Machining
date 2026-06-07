# 任务拖拽重排闪烁

## 问题

工作台任务列表中拖拽任务项更换位置松手后，被拖动的任务项和两个位置之间的所有任务项都会闪一下，包括预览图部分和任务标题部分。

## 根因

`ReorderableListView` 的设计要求 `onReorder` 回调中**同步**更新数据列表，这样 Flutter 内部的拖拽动画和 item 布局能保持在同一帧内一致。

但当前 `MediaTaskListNotifier.reorderTasks` 是 `async Future` 方法，执行路径为：

1. `await` 数据库读取全量任务
2. 在内存中重排
3. `await` 数据库写入全量任务
4. 拿到返回值后 `state = AsyncData(reorderedTasks)`

`onReorder` 触发后，Flutter 已完成拖拽动画但 `state` 仍是旧顺序。等 DB 操作完成、state 更新后，整个列表重建，所有受影响 item 的 widget 在新旧 props 之间跳变，加上 `MediaTaskListTile` 内部 `AnimatedContainer` 的 120ms 过渡动画，放大了视觉闪烁。

## 修复

`media_task_notifier.dart` 的 `reorderTasks` 改为同步方法，采用乐观更新策略：

1. 从内存 `state.requireValue` 直接计算重排结果
2. 立即 `state = AsyncData(reorderedTasks)` 更新 UI
3. `unawaited` 异步持久化到 DB

这样 `ReorderableListView.onReorder` 触发时数据在同一帧内就完成了更新，消除了时序冲突。

同时移除了不再直接引用的 `ReorderMediaTasksUseCase` import（use case 类本身保留）。

## 验证

- 通过 `flutter analyze`。
- 手动验证拖拽排序松手后，所有任务项预览图和标题不再闪烁。

## 后续注意

当 `ReorderableListView.onReorder` 回调中需要异步操作时，应始终先乐观更新 UI 列表数据，再把持久化或副作用放到后台执行。Flutter 的内置拖拽动画依赖同步数据更新才能保持视觉连续性。
