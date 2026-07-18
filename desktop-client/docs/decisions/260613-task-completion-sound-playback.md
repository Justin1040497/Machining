# 260613 任务完成音效使用 Flutter 音频插件

## 状态

有效。

## 背景

任务完成提示音需要播放应用内置的短 WAV 音效，并允许用户在设置页选择或关闭。Windows 上如果通过 PowerShell 创建 `SoundPlayer` 播放，容易被安全软件误拦截或留下不必要的脚本执行痕迹；这类用户可感知提示音不应依赖 shell。

## 决策

任务完成音效由 application 层定义 `TaskCompletionSoundPlayer` 抽象，infrastructure 层实现本地播放服务：

- 音效资源继续放在 `assets/sounds/`，随 Flutter asset 打包。
- 本地播放实现使用 `audioplayers` 直接播放 Flutter asset，不再把 WAV 写入临时目录。
- Windows 不再启动 PowerShell 或脚本命令播放提示音。
- Linux / Web 当前不是发布目标，但依赖本身具备跨平台播放能力。
- 播放失败不能影响任务完成通知和任务状态收尾。

任务完成事件仍从 FFmpeg 队列进入 `AppNotificationManager`；根级 `AppNotificationHost` 在收到成功任务通知时读取当前应用设置并触发播放，避免把 UI 音效副作用塞进 FFmpeg 队列执行器。

## 影响

- 新增 `audioplayers` 作为轻量提示音播放依赖，避免维护自有 Windows 播放通道或 shell 命令。
- 播放能力不再绑定当前桌面发布目标；未来如果要做试听、音量控制或更复杂的声音策略，可以继续扩展 infrastructure 实现。
- 完成音效属于通知展示副作用，不改变任务实体、队列状态或通知持久化语义。
