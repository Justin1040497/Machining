# v1.0.0 版本概览

## 当前事实

`v1.0.0` 是 FrameLean 更名后的首个桌面视频压缩发布版本。这个版本建立了本地视频压缩工作台、任务队列、应用设置、FFmpeg / FFprobe 运行时和 macOS / Windows 发布基础。

## 重要事实设计

| 文档 | 说明 |
| --- | --- |
| `video-compression-workbench.md` | 视频压缩工作台和任务配置设计 |
| `media-task-queue.md` | 本地任务队列、状态流转和执行控制 |
| `ffmpeg-runtime.md` | FFmpeg / FFprobe 运行时定位、命令构造和发布包边界 |

## 设计收益

- 用户不用手写 FFmpeg 命令也能完成常见视频压缩。
- 任务状态、设置和输出配置可持久化，应用重启后可恢复。
- macOS Apple Silicon 和 Windows x64 都有明确发布路径。

## 关联

- `changelog/desktop-client.md`
