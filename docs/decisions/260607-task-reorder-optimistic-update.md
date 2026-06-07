# 任务拖拽排序使用乐观更新

## 状态

有效

## 决策

任务列表拖拽排序时，`MediaTaskListNotifier.reorderTasks` 先基于当前内存 state 计算新顺序并同步更新 UI，再后台持久化 `sort_order`。持久化失败时捕获错误并刷新仓储顺序恢复一致性。

## 原因

`ReorderableListView` 的拖拽动画依赖 `onReorder` 后的数据列表在同一帧内变成新顺序。如果先等待数据库读写完成再更新 state，Flutter 会先结束拖拽动画但 UI 仍使用旧顺序，随后数据库返回后再整段重建，造成任务项预览图和标题闪烁。

## 收益

- 拖拽松手后列表视觉连续。
- 排序只更新 `sort_order`，不会用旧任务快照覆盖运行中任务的进度、状态、错误或输出路径。
- 后台持久化失败可恢复，不会变成未处理异步错误。

## 关联

- `docs/releases/v1.1.5/workbench-theme-and-reorder.md`
- `docs/lessons.md`
