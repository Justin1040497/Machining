# FFmpeg 命令和进程控制

## 所属版本

`v1.1.0`

## 当前事实

`v1.1.0` 强化了 FFprobe 分析字段、FFmpeg 输出参数、音频流映射和跨平台 FFmpeg 进程控制。

## 设计方式

- FFprobe 记录像素格式、位深、色彩范围、色彩矩阵、传递曲线、色彩原色、帧率、宽高比、旋转、场序和音频声道布局等字段。
- FFmpeg 命令构造显式视频 / 音频流映射，避免把不可转码音频流带入输出。
- 输出默认统一到 `yuv420p`、limited range 和 BT.709，降低播放器兼容风险。
- application 层定义 `FfmpegProcessController`，infrastructure 分平台实现暂停、继续和终止。
- Windows runner 原生进程控制通道用于线程挂起 / 恢复，不复用 Unix signal。

## 为什么这样设计

视频源文件差异很大，尤其 iPhone MOV、HDR、HVC1、10-bit 和异常音频流会让简单 FFmpeg 参数失败。命令规划需要利用更多 FFprobe 信息，并把平台进程控制差异隔离在 infrastructure 层。

## 设计收益

- 降低 iPhone MOV 和高风险源素材失败率。
- Windows 暂停 / 继续不再依赖不适用的 Unix signal 语义。
- UI 可以通过统一 use case 控制任务，不感知底层平台差异。

## 关联经验

- `docs/lessons.md#Windows 进程控制不能照搬 Unix signal`
- `docs/lessons.md#iPhone MOV 音频流映射要避开不可转码流`
