# 数据模型

## 文档目的

这份文档记录 Machining 当前落地的数据模型。内容以 `lib/domain` 的实体和值对象、`lib/infrastructure/database` 的 Drift 表，以及仓储映射代码为准。

当前版本只持久化本地任务列表和应用设置；FFmpeg 执行日志、预览帧、缩略图和临时两遍压缩日志仍放在系统临时目录或输出目录附近，不写入 SQLite。

## 数据库总览

Machining 使用 Drift + SQLite。本地数据库由 `AppDatabase` 管理：

```text
lib/infrastructure/database/app_database.dart
```

当前 schema 版本为 `11`，数据库文件名为 `machining.sqlite`，创建在 `path_provider` 返回的应用支持目录中。

当前表：

| 表 | Drift 类 | 用途 |
| --- | --- | --- |
| `tasks` | `TaskRows` | 保存导入媒体任务、执行状态、输出配置、源文件指纹和 FFprobe 分析结果 |
| `settings` | `SettingsRows` | 保存应用级设置；当前只保存一行全局设置，固定 `id = 1` |

## 领域模型关系

核心领域对象：

| 类型 | 位置 | 说明 |
| --- | --- | --- |
| `MediaTask` | `lib/domain/entities/media_task.dart` | 任务主实体，包含文件、状态、配置、分析结果和时间戳 |
| `VideoTaskConfig` | `lib/domain/value_objects/video_task_config.dart` | 单任务视频输出与压缩配置 |
| `MediaAnalysisResult` | `lib/domain/value_objects/media_analysis_result.dart` | FFprobe 解析出的时长、编码、码率、分辨率、音频和封装信息 |
| `SourceFileFingerprint` | `lib/domain/value_objects/source_file_fingerprint.dart` | 源文件快速指纹：文件大小 + 最后修改时间 |
| `AppSettings` | `lib/domain/entities/app_settings.dart` | 应用设置和默认压缩偏好 |
| `AppCompressionSettings` | `lib/domain/value_objects/app_compression_settings.dart` | 应用级压缩默认值，包含默认视频编码和默认推荐方案 |

数据库和领域模型之间的转换由仓储映射完成：

```text
lib/infrastructure/repositories/drift_media_task_repository.dart
lib/infrastructure/repositories/drift_app_settings_repository.dart
lib/infrastructure/repositories/mappers/compression_mode_mapper.dart
```

枚举字段通常使用 Dart enum 的 `.name` 持久化，例如 `TaskStatus.pending` 存为 `pending`。新增、删除或重命名枚举值会直接影响历史数据读取，必须配套迁移或兼容映射。当前 `CompressionMode` 已使用 `CompressionModeMapper` 和 `PersistenceCompatibility` 集中处理历史值兼容。

## `tasks` 表

`tasks` 是任务列表的唯一持久化表。它既保存用户导入的源文件信息，也保存任务执行状态、单任务配置和分析结果。

### 身份、来源和排序字段

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `id` | text | 否 | 无 | `MediaTask.id` | UUID 字符串，主键，由 `MediaTask.generateId()` 生成 |
| `input_path` | text | 否 | 无 | `inputPath` | 源文件绝对路径或系统返回的本地路径 |
| `file_name` | text | 否 | 无 | `fileName` | UI 展示文件名，通常是 `path.basename(inputPath)` |
| `media_kind` | text | 否 | `video` | `mediaKind` | 媒体类型枚举；当前 UI 和命令构造只支持 `video` |
| `purpose` | text | 否 | 无 | `purpose` | 任务用途：`compression` 或 `conversion` |
| `sort_order` | integer | 否 | 无 | `sortOrder` | 任务列表排序，读取时按 `sort_order ASC, created_at ASC` |

### 状态和执行结果字段

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `status` | text | 否 | 无 | `status` | 任务状态，见“任务状态”一节 |
| `progress` | real | 否 | `0` | `progress` | 0 到 1 的进度值；实体构造时断言范围合法 |
| `output_path` | text | 是 | `null` | `outputPath` | FFmpeg 计划生成的输出文件路径 |
| `error_message` | text | 是 | `null` | `errorMessage` | 执行、分析或命令构造失败时保存的用户可见错误 |
| `created_at` | integer | 否 | 无 | `createdAt` | 毫秒时间戳，默认由实体构造时写入 |
| `started_at` | integer | 是 | `null` | `startedAt` | 任务交给 FFmpeg 进程时写入 |
| `completed_at` | integer | 是 | `null` | `completedAt` | FFmpeg 观测到成功完成时写入 |
| `failed_at` | integer | 是 | `null` | `failedAt` | 启动、执行或分析失败时写入 |

### 单任务视频配置字段

这些字段映射到 `VideoTaskConfig`。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `output_format` | text | 否 | 无 | `outputFormat` | 输出封装格式：`mp4`、`mov`、`mkv` |
| `video_codec` | text | 否 | 无 | `videoCodec` | 目标视频编码：`source`、`h264`、`hevc` |
| `encoder_backend` | text | 否 | 无 | `encoderBackend` | 编码器实现：`auto`、`libx264`、`libx265`、`videotoolbox`、`nvenc`、`qsv`、`amf` |
| `resolution_preset` | text | 否 | 无 | `resolutionPreset` | 输出分辨率：原始、2160p、1080p、720p、480p |
| `output_directory` | text | 否 | 无 | `outputDirectory` | 输出目录；空字符串表示跟随源文件目录 |
| `compression_crf` | integer | 否 | `28` | `compressionCrf` | 推荐方案和普通压缩的 CRF 基准值 |
| `compression_mode` | text | 否 | `preset` | `compressionMode` | 压缩控制方式：当前写入 `preset`、`targetSize`；历史值 `smart`、`quality` 会映射为 `preset` |
| `smart_preset` | text | 是 | `null` | `smartPreset` | 推荐方案预设：`balanced`、`chat`、`clear`、`compact` |
| `target_size_bytes` | integer | 是 | `null` | `targetSizeBytes` | 目标体积模式的目标字节数，当前核心字段 |
| `target_size_ratio` | real | 是 | `null` | `targetSizeRatio` | 旧版本兼容字段；没有 `target_size_bytes` 时可按源文件大小换算 |
| `output_file_name` | text | 否 | `''` | `outputFileName` | 用户自定义输出文件名；空字符串时自动生成 |

`VideoTaskConfig.initial()` 的默认值：

| 配置 | 默认值 |
| --- | --- |
| 输出格式 | `mp4` |
| 视频编码 | `h264` |
| 编码器后端 | `auto` |
| 分辨率 | `original` |
| 输出目录 | 空字符串，表示源文件目录 |
| CRF | `28` |
| 压缩模式 | `preset` |
| 推荐方案预设 | `balanced` |
| 目标体积 | `null` |
| 自定义文件名 | 空字符串 |

### 源文件指纹字段

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `source_file_size` | integer | 是 | `null` | `sourceFileFingerprint.fileSize` | 源文件字节数 |
| `source_last_modified_at` | integer | 是 | `null` | `sourceFileFingerprint.lastModifiedAt` | 源文件最后修改时间，毫秒时间戳 |

指纹用于判断任务恢复时源文件是否仍是同一个文件。应用启动加载任务时，如果文件不存在会标记为 `missingSource`；如果文件存在但指纹变化，会清空旧分析结果并重新进入 `analyzing`。

### FFprobe 分析字段

这些字段映射到 `MediaAnalysisResult` 和分析状态信息。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `analysis_duration_ms` | integer | 是 | `null` | `durationMs` | 媒体时长，毫秒 |
| `analysis_video_width` | integer | 是 | `null` | `videoWidth` | 视频宽度 |
| `analysis_video_height` | integer | 是 | `null` | `videoHeight` | 视频高度 |
| `analysis_video_codec` | text | 是 | `null` | `videoCodec` | FFprobe 读取的视频编码名 |
| `analysis_audio_codec` | text | 是 | `null` | `audioCodec` | FFprobe 读取的音频编码名 |
| `analysis_video_bitrate` | integer | 是 | `null` | `videoBitrate` | 视频流码率，单位 bps |
| `analysis_audio_bitrate` | integer | 是 | `null` | `audioBitrate` | 音频流码率，单位 bps |
| `analysis_container_bitrate` | integer | 是 | `null` | `containerBitrate` | 容器总码率，单位 bps |
| `analysis_estimated_bitrate` | integer | 是 | `null` | `estimatedBitrate` | 使用 `fileSize * 8 / durationSeconds` 估算的平均码率 |
| `analysis_container_format` | text | 是 | `null` | `containerFormat` | 容器格式，例如 `mov,mp4,m4a,3gp,3g2,mj2` |
| `analysis_audio_channels` | integer | 是 | `null` | `audioChannels` | 音频声道数 |
| `analysis_audio_sample_rate` | integer | 是 | `null` | `audioSampleRate` | 音频采样率 |
| `analysis_updated_at` | integer | 是 | `null` | `analysisUpdatedAt` | 分析结果写入时间，毫秒时间戳 |
| `analysis_error_message` | text | 是 | `null` | `analysisErrorMessage` | 分析失败或 FFprobe 不可用时的错误信息 |

压缩策略使用 `MediaAnalysisResult.preferredBitrate` 作为有效码率，优先级为：

1. `analysis_video_bitrate`
2. `analysis_container_bitrate`
3. `analysis_estimated_bitrate`

## `settings` 表

`settings` 保存应用级偏好。当前只使用一行，仓储层固定 `id = 1`；如果数据库里没有这一行，`loadSettings()` 会返回 `AppSettings.initial()`。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `id` | integer | 否 | 无 | 固定值 | 当前全局设置固定为 `1` |
| `default_output_directory` | text | 是 | `null` | `defaultOutputDirectory` | 默认输出目录，当前作为设置模型保留 |
| `last_selected_output_directory` | text | 是 | `null` | `lastSelectedOutputDirectory` | 最近一次选择的输出目录 |
| `save_output_to_source_directory` | boolean | 否 | `true` | `saveOutputToSourceDirectory` | 默认导出时是否保存到源文件旁 |
| `custom_ffmpeg_path` | text | 是 | `null` | `customFfmpegPath` | 用户指定的 FFmpeg 可执行文件路径 |
| `custom_ffprobe_path` | text | 是 | `null` | `customFfprobePath` | 用户指定的 FFprobe 可执行文件路径 |
| `show_raw_log` | boolean | 否 | `false` | `showRawLog` | 是否显示原始日志 |
| `show_advanced_options` | boolean | 否 | `false` | `showAdvancedOptions` | 是否展示高级选项 |
| `default_output_video_codec` | text | 否 | `h264` | `compressionSettings.defaultOutputVideoCodec` | 新任务默认视频编码偏好 |
| `default_compression_smart_preset` | text | 否 | `balanced` | `compressionSettings.defaultSmartPreset` | 新任务默认推荐方案；字段名保留 `smart` 是历史命名 |
| `default_output_file_name_template` | text | 否 | `datetimeOriginalCodec` | `defaultOutputFileNameTemplate` | 新任务默认导出文件名模板 |
| `created_at` | integer | 否 | 无 | 仓储维护 | 第一次创建设置行的时间 |
| `updated_at` | integer | 否 | 无 | 仓储维护 | 最近保存设置的时间 |

## 枚举值

### 任务状态

| 存储值 | UI 含义 | 产生位置 |
| --- | --- | --- |
| `pending` | 等待中 | 新任务分析成功后、重试后、重新指定源文件后 |
| `analyzing` | 分析中 | 新导入任务、源文件指纹变化、缺少分析结果时后台分析 |
| `running` | 处理中 | 队列启动 FFmpeg 进程后 |
| `paused` | 已暂停 | 当前前台 FFmpeg 进程被队列执行器挂起后 |
| `completed` | 已完成 | FFmpeg 进程成功退出且输出文件存在 |
| `failed` | 失败 | 分析失败、FFmpeg 不可用、命令构造失败、进程失败或输出缺失 |
| `cancelled` | 已取消 | 用户取消正在执行或暂停中的任务 |
| `missingSource` | 源文件丢失 | 启动、重试或恢复任务时源文件不存在 |

### 任务用途

| 存储值 | 含义 | 当前实现 |
| --- | --- | --- |
| `compression` | 文件压缩 | 当前主路径，使用压缩建议、CRF、目标体积等策略 |
| `conversion` | 格式转换 | 命令构造已支持基础转封装和重编码，UI 仍以压缩工作台为主 |

### 媒体类型

| 存储值 | 含义 | 当前实现 |
| --- | --- | --- |
| `video` | 视频 | 当前唯一支持执行的类型 |
| `image` | 图片 | 枚举已存在，导入时会被拒绝 |
| `audio` | 音频 | 枚举已存在，导入时会被拒绝 |

### 压缩模式

| 存储值 | 含义 | 数据要求 |
| --- | --- | --- |
| `preset` | 推荐方案 | 使用 `smart_preset` 和 `compression_crf`，结合 FFprobe 分析结果估算码率和体积，不强承诺输出大小 |
| `targetSize` | 目标体积 | 优先使用 `target_size_bytes`，需要有效时长；软件编码下使用两遍压缩 |

历史兼容值：

| 历史存储值 | 当前映射 | 说明 |
| --- | --- | --- |
| `smart` | `preset` | 旧“智能推荐”命名，v11 迁移会更新数据库存量记录 |
| `quality` | `preset` | 旧“质量优先”命名，当前不再作为独立压缩模式 |

## 主要数据流

### 导入和分析

1. UI 通过文件选择或拖拽拿到本地路径。
2. `MediaTaskListNotifier.createDraftFromPath()` 调用 `ImportMediaTaskUseCase`。
3. `ImportMediaTaskUseCase` 识别 `MediaKind`，当前只允许 `video`，并读取 `SourceFileFingerprint`。
4. 用应用设置生成新任务默认配置，创建 `MediaTask.draft()`。
5. 写入 `analyzing` 状态并保存到 `tasks`。
6. 后台调用 `AnalyzeMediaTaskUseCase` 和 FFprobe 分析。
7. 成功后写入 `MediaAnalysisResult`，状态从 `analyzing` 回到 `pending`。
8. 失败后写入 `analysis_error_message`，任务状态变为 `failed`。

### 应用启动恢复

1. `MediaTaskListNotifier.build()` 调用 `ReconcileMediaTasksUseCase`。
2. `ReconcileMediaTasksUseCase` 读取全部任务并检查源文件是否存在。
3. 源文件不存在时标记 `missingSource`。
4. 源文件存在但指纹变化时，更新指纹、清空分析结果、重新分析。
5. 缺少分析结果的任务会排入后台分析。
6. 队列执行器刷新状态，判断是否有可执行或暂停任务。

### 执行和进度

1. 队列只从 `pending` 或已有暂停执行中启动任务。
2. 启动前再次检查源文件和 FFmpeg 运行时。
3. 命令构造成功后写入 `running`、`output_path` 和 `started_at`。
4. `LocalFfmpegProcessObserver` 读取 FFmpeg `-progress pipe:1` 输出里的 `out_time_ms`，结合 `analysis_duration_ms` 计算进度。
5. 多步骤计划会把每一步进度按步骤数缩放；目标体积的软件编码两遍压缩就是两步计划。
6. 进程成功且输出文件存在时写入 `completed` 和 `completed_at`。
7. 进程失败、输出文件缺失或监听错误时写入 `failed` 和 `failed_at`。

## 迁移历史

当前迁移逻辑位于 `AppDatabase.migration.onUpgrade`：

| 目标版本 | 变更 |
| --- | --- |
| 2 | 给 `tasks` 增加 `media_kind` |
| 3 | 增加源文件指纹和基础 FFprobe 分析字段 |
| 4 | 增加视频、容器和估算码率字段 |
| 5 | 增加音频码率字段 |
| 6 | 给 `settings` 增加 `default_output_video_codec` |
| 7 | 给 `tasks` 增加 `compression_crf` 和 `output_file_name` |
| 8 | 给 `tasks` 增加 `compression_mode` 和 `target_size_ratio` |
| 9 | 给 `tasks` 增加 `smart_preset` 和 `target_size_bytes` |
| 10 | 给 `settings` 增加保存到源文件旁、默认推荐方案和默认导出文件名模板 |
| 11 | 将 `tasks.compression_mode` 中的历史值 `smart`、`quality` 归一化为 `preset` |

## 修改数据模型的约束

- 新增非空列必须提供 Drift 默认值，或写清楚迁移填充值。
- 枚举持久化值不能随意重命名；确实要重命名时，需要在仓储映射、兼容常量或迁移里兼容旧值。
- 任务状态要能在应用重启后被重新校正；不能假设内存里的 FFmpeg 进程仍存在。
- 源文件、预览帧、日志和输出文件路径都是本地路径，跨机器或用户移动文件后可能失效。
- `target_size_ratio` 是兼容字段，新功能应优先读写 `target_size_bytes`。
- 数据库不保存完整 FFprobe JSON；只保存当前 UI、压缩策略和命令构造需要的字段。

## 后续候选

- `task_logs`：如果需要在 UI 中长期索引历史 FFmpeg 日志，可以把临时日志路径和摘要入库。
- `presets`：如果智能预设开放为用户自定义模板，可以独立成表。
- `benchmark_results`：如果要基于真实素材反馈优化压缩建议，可以保存压缩前后体积、耗时和编码器信息。
- `outputs`：如果一个任务未来支持生成多个输出文件，可以从 `tasks.output_path` 拆出一对多结果表。
