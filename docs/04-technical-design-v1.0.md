# 技术设计 v1.0

## 架构分层

项目采用偏 Clean Architecture 的分层方式：

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

- `domain`：实体、枚举和值对象，不依赖 Flutter UI
- `application`：仓储接口、FFmpeg 命令构造、队列、分析、预览等服务抽象
- `infrastructure`：Drift、FFmpeg/FFprobe、本地文件和进程实现
- `features/workbench`：工作台页面、任务列表和 UI 状态协调

## 核心模块

### 任务模型

`MediaTask` 是主实体，包含：

- 输入文件信息
- 媒体类型
- 任务用途
- 任务状态
- 视频配置
- 进度
- 输出路径
- 错误消息
- FFprobe 分析结果
- 源文件指纹
- 创建、开始、完成、失败时间

### 视频配置

`VideoTaskConfig` 保存单任务参数：

- `outputFormat`
- `videoCodec`
- `encoderBackend`
- `resolutionPreset`
- `outputDirectory`
- `compressionCrf`
- `outputFileName`

### FFmpeg 运行时解析

`LocalFfmpegLocator` 按优先级解析 FFmpeg / FFprobe：

1. 用户自定义路径
2. app bundle 内置路径
3. 开发环境候选路径
4. 系统 PATH

Release 版本的关键路径是：

```text
machining.app/Contents/Resources/ffmpeg/ffmpeg
machining.app/Contents/Resources/ffmpeg/ffprobe
```

### 命令构造

`DefaultFfmpegCommandBuilder` 只负责构造参数，不启动进程。

职责：

- 生成压缩命令
- 生成格式转换命令
- 生成预览片段命令
- 处理输出路径冲突
- 根据码率策略要求用户确认极限压缩

### 队列执行

`DefaultFfmpegTaskQueueRunner` 负责串行执行任务。

职责：

- 启动任务
- 暂停任务
- 恢复任务
- 取消任务
- 维护当前运行上下文
- 后台监听 FFmpeg 进度
- 把完成或失败状态写回仓储

### 进度观测

`LocalFfmpegProcessObserver` 读取 FFmpeg 输出，解析 `out_time_ms` 等进度字段，根据任务时长计算进度。退出码非 0 或输出文件缺失时判定失败。

### 预览帧

`LocalPreviewFrameGenerator` 使用 FFmpeg 生成预览片段和帧图。预览结果和当前配置绑定，配置变化后标记过期。

## 数据存储

使用 Drift + SQLite。

当前表：

- `tasks`
- `settings`

数据库 schema 版本：7。

## macOS 打包

`macos/Runner.xcodeproj/project.pbxproj` 中包含 `Bundle FFmpeg Runtime` 构建阶段，会把：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
```

复制到：

```text
machining.app/Contents/Resources/ffmpeg/
```

如果本地没有二进制，该构建阶段会警告并跳过，避免普通开发构建失败。

## 1.0 技术边界

- 不做跨平台运行时分发
- 不做后台任务守护
- 不做多进程并行压缩
- 不做网络服务
- 不做完整 crash 上报

## 验证命令

```bash
flutter analyze
flutter test
flutter build macos --release
```

验证内置 FFmpeg：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```
