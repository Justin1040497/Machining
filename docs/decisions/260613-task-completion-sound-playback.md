# 260613 任务完成音效使用系统播放器

## 状态

有效。

## 背景

任务完成提示音需要播放应用内置的短 WAV 音效，并允许用户在设置页选择或关闭。当前发布重点是 macOS Universal 2 和 Windows x64，不希望为这一条轻量提示音引入新的音频插件、播放器运行时或额外原生通道维护面。

## 决策

任务完成音效由 application 层定义 `TaskCompletionSoundPlayer` 抽象，infrastructure 层实现本地播放服务：

- Flutter asset 通过 `rootBundle` 读取，并缓存到系统临时目录 `framelean/sounds/`。
- macOS 使用系统 `afplay` 播放缓存后的 WAV。
- Windows 使用系统 `SoundPlayer` 播放缓存后的 WAV。
- Linux / Web 当前不是发布目标，播放服务在非 macOS / Windows 平台不执行播放。
- 播放失败不能影响任务完成通知和任务状态收尾。

任务完成事件仍从 FFmpeg 队列进入 `AppNotificationManager`；根级 `AppNotificationHost` 在收到成功任务通知时读取当前应用设置并触发播放，避免把 UI 音效副作用塞进 FFmpeg 队列执行器。

## 影响

- 不新增音频播放依赖，打包体积和依赖维护面保持稳定。
- 播放能力绑定当前桌面发布目标；未来如果要支持 Linux 或更复杂试听 / 音量控制，需要替换或扩展 infrastructure 实现。
- 完成音效属于通知展示副作用，不改变任务实体、队列状态或通知持久化语义。
