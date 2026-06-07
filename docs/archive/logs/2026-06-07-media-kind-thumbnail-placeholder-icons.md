# 媒体类型缩略图占位图标

## 问题

图片和音频任务没有实际预览图时，任务列表缩略图区域仍显示视频类占位图标。用户会误以为音频和图片任务被当成视频处理。

同类占位显示也存在于任务详情设置弹窗的源文件摘要中。

## 根因

列表缩略图组件只接收 `thumbnail`，没有接收 `MediaKind`，因此空缩略图分支只能固定使用 `Icons.movie_creation_outlined`。

任务详情源文件摘要里的私有缩略图组件也使用了同一个固定视频图标。

## 修复

- 新增 `WorkbenchMediaKindIcon` 展示层映射，将 `MediaKind.video` / `image` / `audio` 分别映射到视频、图片和音频占位图标。
- `MediaTaskThumbnail` 接收 `mediaKind`，任务列表从 `task.mediaKind` 传入。
- `WorkbenchSourceSummary` 的源文件摘要缩略图也按 `task.mediaKind` 选择占位图标。
- 保留现有缩略图加载逻辑：有实际 `ImageProvider` 时仍显示真实预览图。

## 验证

- 新增 widget 回归测试覆盖任务列表中视频 / 图片 / 音频无缩略图占位图标。
- 新增 widget 回归测试覆盖任务详情源文件摘要中视频 / 图片 / 音频无缩略图占位图标。
- 通过 `flutter test test/widget_test.dart`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
