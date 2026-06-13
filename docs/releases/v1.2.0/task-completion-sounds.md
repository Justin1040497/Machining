# v1.2.0 任务完成提示音

## 版本事实

FrameLean 在 v1.2.0 开发期接入任务完成提示音。用户可以在设置页的“应用设置”分区选择“不通知”或 5 个内置短提示音。

提示音设置保存到 `settings.task_completion_sound`，默认值为 `none`。任务完成后，FFmpeg 队列仍只负责发布类型化任务成功通知；根级 `AppNotificationHost` 根据当前设置触发音效播放。

## 播放边界

- 音效资源放在 `assets/sounds/`，通过 `pubspec.yaml` 随应用打包。
- 本地播放实现使用 `audioplayers` 直接播放 Flutter asset。
- Windows 不再启动 PowerShell 或脚本命令播放提示音。
- 播放失败不会影响任务完成通知、通知中心历史或任务状态。

## 验证范围

- 设置模型、Drift 设置映射和设置页保存 / 取消语义。
- 根级任务完成通知触发选中音效。
- 内置音效枚举、asset 路径映射和 `audioplayers` asset key 映射。
- `flutter analyze` 和全量 `flutter test`。
