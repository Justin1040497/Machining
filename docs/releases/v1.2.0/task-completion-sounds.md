# v1.2.0 任务完成提示音

## 版本事实

FrameLean 在 v1.2.0 开发期接入任务完成提示音。用户可以在设置页的“应用设置”分区选择“不通知”或 5 个内置短提示音。

提示音设置保存到 `settings.task_completion_sound`，默认值为 `none`。任务完成后，FFmpeg 队列仍只负责发布类型化任务成功通知；根级 `AppNotificationHost` 根据当前设置触发音效播放。

## 播放边界

- 音效资源放在 `assets/sounds/`，通过 `pubspec.yaml` 随应用打包。
- 播放前把 Flutter asset 写入系统临时目录 `framelean/sounds/`。
- macOS 使用系统 `afplay` 播放。
- Windows 使用系统 `SoundPlayer` 播放。
- 播放失败不会影响任务完成通知、通知中心历史或任务状态。

## 验证范围

- 设置模型、Drift 设置映射和设置页保存 / 取消语义。
- 根级任务完成通知触发选中音效。
- 内置音效枚举和 asset 路径映射。
- `flutter analyze` 和全量 `flutter test`。
