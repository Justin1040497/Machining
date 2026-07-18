# 共享重排列表使用项目内 Flutter fork

## 决策

FrameLean 在 `app/presentation/widgets/reorderable/` 维护基于 Flutter 3.41.2 reorderable 源码的本地 fork，并以 `FrameLeanReorderableListView` 作为业务层唯一公共入口。

共享组件保留 Flutter 的 Overlay 代理、自动滚动、gap 动画和拖拽柄手感，额外提供：

- `move / hold / restoreOrigin` gap 策略。
- `reorder / accepted / cancelled` drop 结果。
- 拖拽更新、取消、drop 完成回调和可配置接收代理。
- 默认关闭、按需开启的跨轴拖动。

fork 保留 Flutter BSD 声明和源版本注释，不修改 Flutter SDK，不导入 `package:flutter/src` 私有 API，不引入第三方拖拽包。

## 理由

Flutter 公共 `ReorderableListView` 不能在特定 hover 区域恢复原始 gap，也不能在保留当前手势的同时将 drop 交给列表外部。纯 `Draggable / DragTarget` 方案则需要重建代理、自动滚动和 gap 动画，手感和回归成本更高。

## 维护约束

- Flutter SDK 升级时，对比 `packages/flutter/lib/src/widgets/reorderable_list.dart` 和 Material `ReorderableListView` 的同版源码。
- 业务特定命中、乐观顺序和持久化仍归 features / application，不进入共享组件。
- 公共回调不在 fork 内部 `setState` 中执行；会重建数据源的提交等 drop 代理卸载后执行。
