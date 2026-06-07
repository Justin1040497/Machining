# 工作台主题和任务拖拽排序

## 所属版本

`v1.1.5`

## 当前事实

工作台建立了 FrameLean 主题 token，支持浅色 / 深色主题切换、首帧主题缓存、响应式桌面尺寸、任务拖拽排序和媒体类型占位图标。

## 设计方式

- `FrameLeanColors` 使用 `ThemeExtension` 承载语义色。
- `FrameLeanApp` 注入浅色和深色主题，并使用 `MaterialApp.router` 的主题动画。
- `AppSettings.themeMode` 保存主题偏好，Drift schema 版本为 15。
- `theme_prefs.json` 作为启动前首帧缓存镜像；启动后以 DB 的 `settings.theme_mode` 为准自愈。
- 工作台顶部栏提供主题切换图标按钮。
- 任务列表使用 `ReorderableListView` 和拖拽手柄调整排序。
- 排序持久化只更新 `sort_order`，避免覆盖运行中任务状态。
- 视频、图片、音频无预览图时显示各自媒体类型占位图标。

## 为什么这样设计

主题系统如果只替换硬编码颜色，后续深色主题会再次重构。使用 `ThemeExtension` 可以让所有工作台组件按语义读取颜色。任务排序如果先等待 DB 再更新 UI，会破坏 `ReorderableListView` 的动画连续性，因此需要同步乐观更新。

## 设计收益

- 深浅主题复用同一套 token 调用方式。
- 用户上次选择深色时，应用首帧就是深色。
- 拖拽排序视觉连续，且不会覆盖任务执行状态。
- 媒体类型展示更准确，不再让图片 / 音频显示视频占位图标。

## 当前边界

- 暂不支持跟随系统主题。
- 暂不支持用户自定义主题色。
- 暂不做截图 golden 回归。

## 关联

- `docs/decisions/260607-task-reorder-optimistic-update.md`
- `docs/lessons.md#ReorderableListView 需要同步更新列表数据`
- `docs/lessons.md#拖拽列表项内避免 Tooltip overlay`
- `docs/lessons.md#主题启动缓存只能作为首帧镜像`
