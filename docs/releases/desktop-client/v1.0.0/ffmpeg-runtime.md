# FFmpeg / FFprobe 运行时基础

## 所属版本

`v1.0.0`

## 当前事实

FrameLean 通过本地 FFmpeg / FFprobe 执行媒体分析和压缩。运行时可来自用户自定义路径、应用包内置路径、系统常见路径或 `PATH`。

## 设计方式

- `LocalFfmpegLocator` 负责解析 `ffmpeg` / `ffprobe`。
- FFprobe 用于分析源文件信息。
- FFmpeg 命令构造集中在 application 抽象和 infrastructure 实现中。
- macOS 和 Windows 发布包都要求存在对应平台运行时。

## 为什么这样设计

FFmpeg 是核心能力来源，但不同用户机器上的安装路径和编码器能力差异很大。运行时定位和能力检测集中化可以降低 UI 和业务逻辑复杂度。

## 设计收益

- 支持内置运行时，降低用户配置成本。
- 支持自定义路径，方便开发和高级用户。
- 后续可按平台扩展编码器优先级和发布包校验。

## 边界

- FFmpeg 二进制不提交到 Git。
- 包含 FFmpeg + x264 等运行时的发布包需要遵守对应许可证要求。
