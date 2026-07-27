# 数据模型

## 文档目的

这份文档记录 FrameLean 当前落地的数据模型。内容以 `lib/domain` 的实体和值对象、`lib/infrastructure/database` 的 Drift 表，以及仓储映射代码为准。

当前版本持久化本地任务列表、任务夹、应用设置、FEngine Snapshot 投影和应用通知记录；预览帧、缩略图和执行日志缓存仍放在系统临时目录或输出目录附近，不写入 SQLite。

## 数据库总览

FrameLean 使用 Drift + SQLite。本地数据库由 `AppDatabase` 管理：

```text
lib/infrastructure/database/app_database.dart
```

当前 schema 版本为 `30`，数据库文件名为 `framelean.sqlite`，创建在 `path_provider` 返回的应用支持目录中。

当前表：

| 表 | Drift 类 | 用途 |
| --- | --- | --- |
| `tasks` | `TaskRows` | 保存导入媒体任务、本地展示状态、输出配置和源文件指纹；可配置的媒体事实以 FEngine Snapshot 投影为准 |
| `task_folders` | `TaskFolderRows` | 保存工作台任务夹、媒体类型、排序和任务夹默认配置 |
| `settings` | `SettingsRows` | 保存应用级设置；当前只保存一行全局设置，固定 `id = 1` |
| `app_notifications` | `AppNotificationRows` | 保存应用内通知历史，供全局提示和后续通知中心读取 |

## 领域模型关系

核心领域对象：

| 类型 | 位置 | 说明 |
| --- | --- | --- |
| `MediaTask` | `lib/domain/entities/media_task.dart` | 任务主实体，包含文件、状态、配置、分析结果、完成输出体积和时间戳 |
| `TaskFolder` | `lib/domain/entities/task_folder.dart` | 工作台任务夹实体，包含名称、媒体类型、排序和默认配置 |
| `MediaTaskConfig` | `lib/domain/value_objects/media_task_config.dart` | 单任务通用输出、压缩和分类型配置入口 |
| `VideoProcessingConfig` | `lib/domain/value_objects/video_processing_config.dart` | 视频输出与压缩配置 |
| `ImageProcessingConfig` | `lib/domain/value_objects/image_processing_config.dart` | 图片输出格式、分辨率、质量、无损压缩和元数据保留配置 |
| `AudioProcessingConfig` | `lib/domain/value_objects/audio_processing_config.dart` | 音频输出格式、码率、采样率和声道配置 |
| `VideoTaskConfig` | `lib/domain/value_objects/video_task_config.dart` | 旧视频配置兼容对象，可映射到 `MediaTaskConfig.video` |
| `MediaAnalysisResult` | `lib/domain/value_objects/media_analysis_result.dart` | FEngine/FLL 分析投影出的时长、编码、码率、分辨率、音频、封装、色彩和 HDR / Dolby Vision 元数据 |
| `SourceFileFingerprint` | `lib/domain/value_objects/source_file_fingerprint.dart` | 源文件快速指纹：文件大小 + 最后修改时间 |
| `TaskFailure` | `lib/domain/value_objects/task_failure.dart` | 当前失败的唯一权威信息，保存阶段、错误码、用户提示、技术摘要、发生时间和可重试性；恢复动作由阶段与错误码推导 |
| `AppSettings` | `lib/domain/entities/app_settings.dart` | 应用设置、默认媒体处理配置和主题偏好 |
| `AppCompressionSettings` | `lib/domain/value_objects/app_compression_settings.dart` | 应用级压缩默认值，包含默认视频编码和默认推荐方案 |
| `AppNotificationEntry` | `lib/domain/entities/app_notification_entry.dart` | 应用通知记录，包含类型、级别、标题、正文、来源、创建时间和已读 / 关闭状态 |
| `AppReleaseInfo` / `AppUpdateState` | `lib/domain/value_objects/app_release_info.dart`、`lib/domain/value_objects/app_update_state.dart` | 可用版本、GitHub / Gitee / 备用下载地址、可选 package 元数据、下载进度和安装状态 |
| `MediaTaskPolicyTag` | `lib/domain/enums/media_task_policy_tag.dart` | 任务自动策略标签，用于展示透明保留、输出改名、目录创建、图片 fallback 和未有效压缩 |

数据库和领域模型之间的转换由仓储映射完成：

```text
lib/infrastructure/repositories/drift_media_task_repository.dart
lib/infrastructure/repositories/drift_app_settings_repository.dart
lib/infrastructure/repositories/drift_app_notification_repository.dart
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
| `media_kind` | text | 否 | `video` | `mediaKind` | 媒体类型枚举；当前支持 `video`、`image`、`audio` 导入和经 FEngine 的分析 / 执行 |
| `purpose` | text | 否 | 无 | `purpose` | 任务用途：`compression` 或 `conversion` |
| `sort_order` | integer | 否 | 无 | `sortOrder` | 任务列表排序，读取时按 `sort_order ASC, created_at ASC` |
| `folder_id` | text | 是 | `null` | `folderId` | 任务所属任务夹 ID；为空时任务显示在工作台总列表 |
| `folder_sort_order` | integer | 是 | `null` | `folderSortOrder` | 任务在夹内的排序；移出任务夹后清空 |

### 状态和执行结果字段

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `status` | text | 否 | 无 | `status` | 任务状态，见“任务状态”一节 |
| `progress` | real | 否 | `0` | `progress` | 0 到 1 的进度值；实体构造时断言范围合法 |
| `output_path` | text | 是 | `null` | `outputPath` | FEngine 接受的 execution selection 所对应的输出文件路径 |
| `output_file_size` | integer | 是 | `null` | `outputFileSize` | 成功完成后记录的最终输出体积；重试或重新执行时清空 |
| `failure_json` | text | 是 | `null` | `failure` | schema 30 的结构化失败 JSON，固定 `version: 1`；读取优先于旧错误列 |
| `error_message` | text | 是 | `null` | 兼容镜像 | 暂保留的旧技术错误列；新写入同步 `TaskFailure.technicalSummary`，不再作为领域权威信息 |
| `analysis_error_message` | text | 是 | `null` | 兼容镜像 | 暂保留的旧分析错误列；分析失败时同步用户提示，用于旧数据库 / 旧客户端降级兼容 |
| `policy_tags_json` | text | 是 | `null` | `policyTags` | 任务自动策略标签 JSON 数组；为空表示没有标签 |
| `created_at` | integer | 否 | 无 | `createdAt` | 毫秒时间戳，默认由实体构造时写入 |
| `started_at` | integer | 是 | `null` | `startedAt` | FEngine execution 进入运行态时写入 |
| `completed_at` | integer | 是 | `null` | `completedAt` | FEngine 终态事件确认完成时写入 |
| `failed_at` | integer | 是 | `null` | `failedAt` | 启动、执行或分析失败时写入 |

### 单任务配置字段

`media_config_json` 是新的通用配置主字段，映射到 `MediaTaskConfig`。旧视频列仍保留并继续写入，用于兼容历史数据和降低回滚风险；读取时优先使用 `media_config_json`，缺失时再从旧视频列构造 `MediaTaskConfig.video`。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `media_config_json` | text | 是 | `null` | `MediaTask.config` | JSON 配置，包含通用输出字段以及 `video` / `image` / `audio` 分类型配置 |

### 兼容视频配置字段

这些字段是旧视频配置列。新任务保存时仍写入这些字段；对图片和音频任务，仓储使用默认视频配置填充旧列，真实配置以 `media_config_json` 为准。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `output_format` | text | 否 | 无 | `outputFormat` | 输出封装格式：`mp4`、`mov`、`mkv`、`webm`、`avi` |
| `video_codec` | text | 否 | 无 | `videoCodec` | 目标视频编码：`source`、`h264`、`hevc`、`vp9`、`av1`、`proRes`、`mpeg4`、`mjpeg` |
| `encoder_backend` | text | 否 | 无 | `encoderBackend` | 编码器实现：`auto`、`libx264`、`libx265`、`libvpxVp9`、`libsvtav1`、`proresKs`、`nativeMpeg4`、`nativeMjpeg`、`videotoolbox`、`nvenc`、`qsv`、`amf` |
| `resolution_preset` | text | 否 | 无 | `resolutionPreset` | 输出分辨率：原始、2160p、1080p、720p、480p |
| `output_directory` | text | 否 | 无 | `outputDirectory` | 输出目录；空字符串表示跟随源文件目录 |
| `compression_crf` | integer | 否 | `28` | `compressionCrf` | 推荐方案和普通压缩的 CRF 基准值 |
| `compression_mode` | text | 否 | `preset` | `compressionMode` | 压缩控制方式：当前写入 `preset`、`targetSize`；历史值 `smart`、`quality` 会映射为 `preset` |
| `smart_preset` | text | 是 | `null` | `smartPreset` | 推荐方案预设：`balanced`、`chat`、`clear`、`compact` |
| `target_size_bytes` | integer | 是 | `null` | `targetSizeBytes` | 目标体积模式的目标字节数，当前核心字段 |
| `target_size_ratio` | real | 是 | `null` | `targetSizeRatio` | 旧版本兼容字段；没有 `target_size_bytes` 时可按源文件大小换算 |
| `output_file_name` | text | 否 | `''` | `outputFileName` | 用户自定义输出文件名；空字符串时自动生成 |

视频默认配置的兼容默认值：

| 配置 | 默认值 |
| --- | --- |
| 输出格式 | `mp4` |
| 视频编码 | `h264` |
| 编码器后端 | `auto` |
| 分辨率 | `original` |
| 输出目录 | 空字符串，表示源文件目录 |
| CRF | `28` |
| 压缩模式 | `preset` |
| 推荐方案预设 | `chat` |
| 目标体积 | `null` |
| 自定义文件名 | 空字符串 |

`media_config_json` 当前写入结构包含：

| JSON 字段 | 说明 |
| --- | --- |
| `configVersion` | 当前为 `2` |
| `outputLocationMode` | 输出位置模式：`system` 表示执行时读取最新系统设置，`source` 表示源文件旁，`custom` 表示使用 `outputDirectory` |
| `outputDirectory` / `outputFileName` | 通用自定义输出目录和文件名；旧 JSON 缺少 `outputLocationMode` 时，空目录迁移为 `source`，非空目录迁移为 `custom` |
| `compressionMode` / `preset` / `targetSizeBytes` / `targetSizeRatio` | 通用处理策略字段 |
| `video` | 视频格式、是否保持源格式、编码器、后端、HDR 输出模式、HDR 开启前的编码恢复值、分辨率、CRF、元数据保留开关和旧推荐预设 |
| `image` | 图片格式、是否保持源格式、无损压缩开关、分辨率预设、质量和元数据保留开关；输出编码由后台按图片格式推导 |
| `audio` | 音频格式、是否保持源格式、码率、采样率、声道和元数据保留开关；当前输出格式包含 `mp3`、`m4a`、`aac`、`wav`、`flac`、`aiff`、`wma`、`opus`、`oggOpus`，输出编码由后台按音频格式推导 |

`keepOriginalOutputFormat` 不保存伪格式。导入任务时会按源文件扩展名解析成真实 `MediaOutputFormat`，例如 `.mp4` 写入 `mp4`、`.mov` 写入 `mov`、`.png` 写入 `png`、`.ogg` 写入 `oggOpus`；不支持的源格式会回退到默认输出格式并关闭保持状态。应用默认设置中视频、图片、音频均默认开启保持源文件格式。视频 `hdrOutputMode` 当前支持 `convertToSdr` 和 `preserveHdr`。`preserveHdr` 只承诺 HDR10 / HLG 基础 10-bit HEVC 输出和基础色彩标记，不承诺保留 Dolby Vision 动态元数据。视频、图片和音频 `preserveMetadata` 缺省均为 `true`。

图片 `losslessCompression` 缺省为 `false`，旧 JSON 缺失该字段时同样按 `false` 读取。无损压缩当前只允许 PNG、WebP 和 TIFF；格式转换用途不会沿用压缩用途中的无损开关。

### 源文件指纹字段

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `source_file_size` | integer | 是 | `null` | `sourceFileFingerprint.fileSize` | 源文件字节数 |
| `source_last_modified_at` | integer | 是 | `null` | `sourceFileFingerprint.lastModifiedAt` | 源文件最后修改时间，毫秒时间戳 |

指纹用于判断任务恢复时源文件是否仍是同一个文件。应用启动加载任务时，如果文件不存在会标记为 `missingSource`；如果文件存在但指纹变化，会清空旧分析结果并重新进入 `analyzing`。

### 媒体分析镜像字段

这些字段映射到 `MediaAnalysisResult` 和分析状态信息。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `analysis_duration_ms` | integer | 是 | `null` | `durationMs` | 媒体时长，毫秒 |
| `analysis_video_width` | integer | 是 | `null` | `videoWidth` | 视频宽度 |
| `analysis_video_height` | integer | 是 | `null` | `videoHeight` | 视频高度 |
| `analysis_video_codec` | text | 是 | `null` | `videoCodec` | FLL libav 分析出的主视频编码名 |
| `analysis_audio_codec` | text | 是 | `null` | `audioCodec` | FLL libav 分析出的主音频编码名 |
| `analysis_video_pixel_format` | text | 是 | `null` | `videoPixelFormat` | 视频像素格式，例如 `yuv420p`、`p010le` |
| `analysis_video_bit_depth` | integer | 是 | `null` | `videoBitDepth` | 视频位深，优先读取 `bits_per_raw_sample`，缺失时从像素格式推断 |
| `analysis_color_range` | text | 是 | `null` | `colorRange` | 视频色彩范围，例如 `tv`、`pc` |
| `analysis_color_space` | text | 是 | `null` | `colorSpace` | 视频色彩矩阵 / colorspace，例如 `bt709`、`bt2020nc` |
| `analysis_color_transfer` | text | 是 | `null` | `colorTransfer` | 视频传递曲线，例如 `bt709`、`smpte2084`、`arib-std-b67` |
| `analysis_color_primaries` | text | 是 | `null` | `colorPrimaries` | 视频色彩原色，例如 `bt709`、`bt2020` |
| `analysis_chroma_location` | text | 是 | `null` | `chromaLocation` | 视频色度采样位置，例如 `left`、`center` |
| `analysis_mastering_display_metadata` | text | 是 | `null` | `masteringDisplayMetadata` | HDR10 Mastering Display 原始关键字段摘要 |
| `analysis_mastering_display_max_luminance` | real | 是 | `null` | `masteringDisplayMaxLuminance` | HDR10 Mastering Display 最大亮度，单位 nits |
| `analysis_max_content_light_level` | integer | 是 | `null` | `maxContentLightLevel` | HDR10 MaxCLL，单位 nits |
| `analysis_max_frame_average_light_level` | integer | 是 | `null` | `maxFrameAverageLightLevel` | HDR10 MaxFALL，单位 nits |
| `analysis_dolby_vision_profile` | integer | 是 | `null` | `dolbyVisionProfile` | Dolby Vision Profile，例如 `5`、`8` |
| `analysis_dolby_vision_compatibility_id` | integer | 是 | `null` | `dolbyVisionCompatibilityId` | Dolby Vision BL signal compatibility id，用于判断是否有 HDR10 兼容层 |
| `analysis_average_frame_rate` | text | 是 | `null` | `averageFrameRate` | FLL 分析得到的平均帧率文本 |
| `analysis_real_frame_rate` | text | 是 | `null` | `realFrameRate` | FLL 分析得到的实际帧率文本 |
| `analysis_sample_aspect_ratio` | text | 是 | `null` | `sampleAspectRatio` | 视频像素宽高比 |
| `analysis_display_aspect_ratio` | text | 是 | `null` | `displayAspectRatio` | 视频显示宽高比 |
| `analysis_video_rotation_degrees` | integer | 是 | `null` | `videoRotationDegrees` | FLL 从容器标签或 side data 读取的旋转角度 |
| `analysis_field_order` | text | 是 | `null` | `fieldOrder` | 扫描方式 / 场序信息 |
| `analysis_video_bitrate` | integer | 是 | `null` | `videoBitrate` | 视频流码率，单位 bps |
| `analysis_audio_bitrate` | integer | 是 | `null` | `audioBitrate` | 音频流码率，单位 bps |
| `analysis_container_bitrate` | integer | 是 | `null` | `containerBitrate` | 容器总码率，单位 bps |
| `analysis_estimated_bitrate` | integer | 是 | `null` | `estimatedBitrate` | 使用 `fileSize * 8 / durationSeconds` 估算的平均码率 |
| `analysis_container_format` | text | 是 | `null` | `containerFormat` | 容器格式，例如 `mov,mp4,m4a,3gp,3g2,mj2` |
| `analysis_audio_channels` | integer | 是 | `null` | `audioChannels` | 音频声道数 |
| `analysis_audio_sample_rate` | integer | 是 | `null` | `audioSampleRate` | 音频采样率 |
| `analysis_audio_channel_layout` | text | 是 | `null` | `audioChannelLayout` | 音频声道布局，例如 `mono`、`stereo`、`5.1(side)` |
| `analysis_audio_stream_index` | integer | 是 | `null` | `audioStreamIndex` | FLL 选出的主音频流全局索引；仅作展示和 selection 事实镜像，不由 Client 生成 stream mapping 参数 |
| `analysis_image_width` | integer | 是 | `null` | `imageWidth` | 图片宽度 |
| `analysis_image_height` | integer | 是 | `null` | `imageHeight` | 图片高度 |
| `analysis_image_codec` | text | 是 | `null` | `imageCodec` | FLL libav 分析出的图片编码名 |
| `analysis_image_pixel_format` | text | 是 | `null` | `imagePixelFormat` | 图片像素格式 |
| `analysis_image_bit_depth` | integer | 是 | `null` | `imageBitDepth` | 图片位深 |
| `analysis_updated_at` | integer | 是 | `null` | `analysisUpdatedAt` | 分析结果写入时间，毫秒时间戳 |
| `analysis_error_message` | text | 是 | `null` | `analysisErrorMessage` | FEngine 分析失败时的展示错误信息 |

压缩策略使用 `MediaAnalysisResult.preferredBitrate` 作为有效码率，优先级为：

1. `analysis_video_bitrate`
2. `analysis_audio_bitrate`
3. `analysis_container_bitrate`
4. `analysis_estimated_bitrate`

## `task_folders` 表

`task_folders` 保存工作台任务夹。任务夹是本地批处理分组，不映射真实系统文件夹；删除任务夹只释放夹内任务，不删除任务或源文件。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `id` | text | 否 | 无 | `TaskFolder.id` | UUID 字符串，主键 |
| `name` | text | 否 | 无 | `name` | 工作台展示名称 |
| `media_kind` | text | 否 | 无 | `mediaKind` | 任务夹媒体类型；首版不混放视频 / 图片 / 音频 |
| `sort_order` | integer | 否 | 无 | `sortOrder` | 任务夹在工作台总列表中的排序 |
| `default_config_json` | text | 否 | 无 | `defaultConfig` | 任务夹默认媒体处理配置，使用 `MediaTaskConfig` JSON 结构 |
| `created_at` | integer | 否 | 无 | `createdAt` | 创建时间毫秒时间戳 |
| `updated_at` | integer | 否 | 无 | `updatedAt` | 更新时间毫秒时间戳 |

## `settings` 表

`settings` 保存应用级偏好。当前只使用一行，仓储层固定 `id = 1`；如果数据库里没有这一行，`loadSettings()` 会返回 `AppSettings.initial()`。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `id` | integer | 否 | 无 | 固定值 | 当前全局设置固定为 `1` |
| `default_output_directory` | text | 是 | `null` | `defaultOutputDirectory` | 默认输出目录，当前作为设置模型保留 |
| `last_selected_output_directory` | text | 是 | `null` | `lastSelectedOutputDirectory` | 最近一次选择的输出目录 |
| `save_output_to_source_directory` | boolean | 否 | `true` | `saveOutputToSourceDirectory` | 默认导出时是否保存到源文件旁 |
| `show_raw_log` | boolean | 否 | `false` | `showRawLog` | 是否显示原始日志 |
| `show_advanced_options` | boolean | 否 | `false` | `showAdvancedOptions` | 是否展示高级选项 |
| `default_output_video_codec` | text | 否 | `h264` | `compressionSettings.defaultOutputVideoCodec` | 新任务默认视频编码偏好 |
| `default_compression_smart_preset` | text | 否 | `chat` | `compressionSettings.defaultSmartPreset` | 新任务默认推荐方案；字段名保留 `smart` 是历史命名 |
| `default_output_file_name_template` | text | 否 | `{source}-{action}` | `defaultOutputFileNameTemplate` | 新任务默认导出文件名模板字符串；支持 `{source}`、`{date}`、`{version}`、`{action}`、`{codec}`、`{encoder}`；`codec` 输出 `h264 / h265`，`encoder` 输出 `x264 / x265 / videotoolbox / nvenc / qsv / amf` 等实际编码器 token，`auto` 会按目标编码保守解析为 `x264` 或 `x265`；数字之间的 `x / X` 会规范化为 `×`，历史枚举值由仓储读取时兼容映射 |
| `default_media_config_json` | text | 是 | `null` | `defaultMediaConfig` | 通用默认媒体处理配置 JSON；读取时优先于旧视频默认字段，保存时继续同步旧视频字段以便回滚 |
| `theme_mode` | text | 否 | `system` | `themeMode` | 应用主题偏好；当前支持 `system`、`light`、`dark`，是主题设置的 source of truth |
| `hide_notification_badge` | boolean | 否 | `true` | `hideNotificationBadge` | 是否隐藏工作台右上角通知未读角标；不影响通知持久化、未读状态或通知中心入口 |
| `show_task_completion_dialog` | boolean | 否 | `true` | 旧兼容列 | 历史完成弹窗偏好列；当前 domain / UI 不再映射为可修改设置，任务完成只走完成提示音、通知中心和任务项完成文件入口 |
| `task_completion_sound` | text | 否 | `clean_success` | `taskCompletionSound` | 任务完成后播放的提示音选择；`none` 表示不播放，其他值映射到随包内置的 `assets/sounds/` WAV 提示音 |
| `max_concurrent_executions` | integer | 否 | `2` | `maxConcurrentExecutions` | 用户期望的最大并行任务数，领域层归一化到 1 到 3；实际运行并发还会由资源守卫按 CPU、内存和运行任务类型降级 |
| `folder_import_scan_depth` | integer | 否 | `2` | `folderImportScanDepth` | 文件夹导入递归扫描深度，领域层归一化到 0 到 5；层级越深，导入前遍历时间越长 |
| `notification_policies_json` | text | 否 | `{}` | `notificationPolicies` | 按 `NotificationEventType` 保存通知投递策略；缺失事件按领域默认补齐 |
| `shortcut_bindings_json` | text | 否 | `{}` | `shortcutBindings` | 按 `AppShortcutAction` 保存快捷键绑定；缺失动作按默认快捷键补齐 |
| `close_behavior` | text | 否 | `background` | `closeBehavior` | 点击窗口关闭时的行为：`background` 最小化到后台，`quit` 退出应用 |
| `created_at` | integer | 否 | 无 | 仓储维护 | 第一次创建设置行的时间 |
| `updated_at` | integer | 否 | 无 | 仓储维护 | 最近保存设置的时间 |

主题启动另有轻量缓存镜像 `theme_prefs.json`，位于应用支持目录，只保存 `themeMode` 用于首帧渲染。缓存文件损坏或丢失时回退 `light`；应用启动后会异步读取 `settings.theme_mode`，若 DB 与缓存不同，则以 DB 为准更新当前主题并重写缓存。

## `app_notifications` 表

`app_notifications` 保存应用内通知历史。业务代码通过 `AppNotificationManager` 记录通知；根级通知 Host 订阅同一 manager 的展示事件并弹出临时提示。通知中心面板读取这张表，而不是从页面局部状态拼装历史。`AppNotificationKind.interaction` 只用于临时交互提示，不写入这张表。

| 字段 | 类型 | 可空 | 默认值 | 领域字段 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `id` | text | 否 | 无 | `id` | UUID 字符串，主键 |
| `kind` | text | 否 | `general` | `kind` | 通知类型：`general`、`settings`、`task`、`update`；`interaction` 为临时展示类型，正常不持久化 |
| `level` | text | 否 | 无 | `level` | 通知级别：`info`、`success`、`warning`、`error` |
| `title` | text | 否 | 无 | `title` | 通知标题 |
| `message` | text | 否 | `''` | `message` | 通知正文或失败原因 |
| `source` | text | 否 | 无 | `source` | 通知来源，例如 `settings`、`workbench` |
| `dedupe_key` | text | 是 | `null` | `dedupeKey` | 通知去重键；版本更新通知使用 `update:{platform}:{version}:{buildNumber}` |
| `created_at` | integer | 否 | 无 | `createdAt` | 通知创建时间，毫秒时间戳 |
| `read_at` | integer | 是 | `null` | `readAt` | 通知被标记为已读的时间 |
| `dismissed_at` | integer | 是 | `null` | `dismissedAt` | 通知被关闭或归档的时间 |
| `payload_json` | text | 是 | `null` | `payloadJson` | 通知中心动作扩展载荷；任务通知当前保存 `taskId`、`fileName`、可选 `outputPath`、源 / 输出体积、耗时、失败原因和失败建议 |

通知中心只读取 `dismissed_at IS NULL` 的记录。打开通知中心会批量填写未读记录的 `read_at`；清扫会批量填写 `dismissed_at`，保留历史数据但不再展示。任务成功通知通过 `kind = task`、`level = success` 和 `payload_json.outputPath` 解析“打开输出文件位置”动作，并在正文展示体积、压缩比例、保存路径和耗时。版本更新通知通过 `kind = update`、`dedupe_key` 和 `payload_json` 中的版本、平台、构建号、日志摘要及 GitHub / Gitee / 备用地址解析 L2 更新通知和外部下载动作。

## 枚举值

### 任务状态

| 存储值 | UI 含义 | 产生位置 |
| --- | --- | --- |
| `await_analysis` | 等待分析 | 新导入、重新分析、源文件变化或分析中断恢复后 |
| `analysis_queued` | 已入分析队列 | FEngine 已接受请求，等待分析工作派发 |
| `analyzing` | 分析中 | FEngine 分析队列已经派发该任务 |
| `ready` | 等待开始 | 已持久化有效 FLL Snapshot，等待用户启动或重试 |
| `analysis_failed` | 分析失败 | FEngine 分析终态失败 |
| `execution_queued` | 已入执行队列 | FEngine 已接受 execution selection，等待或准备启动 |
| `running` | 处理中 | FEngine execution lane 正在执行该任务 |
| `preempting` | 正在抢占 | FEngine 正在暂停当前 execution 以启动前台任务 |
| `preempted` | 已抢占 | 已暂停并位于 FEngine LIFO 恢复栈 |
| `resuming` | 正在恢复 | FEngine 正在从恢复栈重启该 execution |
| `paused` | 已暂停 | FEngine 对 execution 发出暂停或抢占事件后 |
| `completed` | 已完成 | FEngine 终态事件确认完成且输出 artifact 有效 |
| `execution_failed` | 执行失败 | FEngine 执行失败，或输出 artifact 缺失 |
| `cancelled` | 已取消 | 用户取消正在执行或暂停中的任务 |
| `missing_source` | 源文件丢失 | 启动、重试或恢复任务时源文件不存在 |

### 任务用途

| 存储值 | 含义 | 当前实现 |
| --- | --- | --- |
| `compression` | 文件压缩 | Client 从 FLL Snapshot 展示压缩候选、预设和估算 |
| `conversion` | 格式转换 | Client 从 FLL Snapshot 展示可用格式和参数；实际执行链由 FLL 判定 |

### 媒体类型

| 存储值 | 含义 | 当前实现 |
| --- | --- | --- |
| `video` | 视频 | 支持 FLL 分析、FEngine 配置与执行、预览帧和缩略图主链路 |
| `image` | 图片 | 支持导入、FLL 分析、缩略图、图片配置面板和经 FEngine 的执行 |
| `audio` | 音频 | 支持导入、FLL 分析和经 FEngine 的执行；波形、试听和音频编辑不在当前范围 |

### 压缩模式

| 存储值 | 含义 | 数据要求 |
| --- | --- | --- |
| `preset` | 推荐方案 | Client 从 FLL Snapshot 展示可选预设和伴随参数；不在本地估算或组装 native 命令 |
| `targetSize` | 目标体积 | 将目标字节数与候选 ID 原样提交给 FEngine；可行性和执行链由 FLL 判定 |

历史兼容值：

| 历史存储值 | 当前映射 | 说明 |
| --- | --- | --- |
| `smart` | `preset` | 旧“智能推荐”命名，v11 迁移会更新数据库存量记录 |
| `quality` | `preset` | 旧“质量优先”命名，当前不再作为独立压缩模式 |

## 主要数据流

### 导入和分析

1. UI 通过文件选择或拖拽拿到本地路径。
2. `MediaTaskListNotifier.createDraftFromPath()` 调用 `ImportMediaTaskUseCase`。
3. `ImportMediaTaskUseCase` 识别 `MediaKind`，允许 `video`、`image`、`audio`，并读取 `SourceFileFingerprint`。
4. 用应用设置和媒体类型生成新任务默认 `MediaTaskConfig`，创建 `MediaTask.draft()`。
5. 批量写入 `await_analysis` 状态后，Client 通过 `AnalyzeMediaTaskUseCase` 把源事实提交给 FEngine 分析队列。
6. FEngine 接受并派发后，Client 将状态投影为 `analyzing`。
7. `AnalysisCompleted(analysisId, revision, snapshot)` 到达后，Client 持久化 Snapshot 投影和展示镜像，再转为 `ready` / 等待用户启动。
8. 分析失败事件写入 `TaskFailure(stage: analysis, ...)`，任务状态转为 `analysis_failed`。

### 应用启动恢复

1. `MediaTaskListNotifier.build()` 调用 `ReconcileMediaTasksUseCase`。
2. `ReconcileMediaTasksUseCase` 读取全部任务并检查源文件是否存在。
3. 源文件不存在时标记 `missingSource`。
4. 源文件存在但指纹变化时，更新指纹、使 Snapshot 投影失效并转为 `await_analysis`。
5. 没有有效 Snapshot 的旧任务会对账为 `await_analysis` 并重新提交 FEngine；带有效 Snapshot 的 `ready` 任务保持不变。
6. Client 读取 FEngine Engine Snapshot，对账分析队列、execution lane、LIFO 恢复栈与任务展示状态。

### 执行和进度

1. 全新执行只接受持有有效 FLL Snapshot 的 `ready` 任务；Client 把用户选择的 candidate、preset 与参数原样提交给 FEngine。
2. FEngine 以 source facts 与 Snapshot revision 再次校验准入；Client 不在本地解析配置、构造命令或预检 native 执行能力。
3. 执行 lane、普通等待队列、用户暂停队列和 LIFO 恢复栈均由 FEngine 维护，Client 只投影其 Snapshot 与事件。
4. 用户手动启动等待任务时，FEngine `PreemptAndStart` 暂停当前活动 execution 并压入恢复栈；最后一次抢占的任务最先恢复。
5. FEngine 接受 execution 后，Client 写入 execution ID、队列 revision 与运行态投影；工作台展示由后续状态事件持续更新。
6. 进度来自 FEngine 的 `media_time_us`、已处理字节与 execution 状态事件；Client 不读取进程 stdout 或推导编码步骤。
7. 完成事件确认输出 artifact 后写入 `completed`、`completed_at` 与输出信息。
8. 失败、取消或 source facts 不匹配时写入对应终态和 `failure_json`；通知只展示面向用户的错误信息，诊断由 FEngine 提供。

## 迁移历史

当前迁移逻辑位于 `AppDatabase.migration.onUpgrade`。所有 `addColumn` 调用通过 `_safeAddColumn` helper 实现幂等（若列已存在则安全跳过），防止开发阶段反复打包时因 Drift `onCreate` 已创建完整表而导致 `duplicate column name` 错误。新增列时继续使用 `_safeAddColumn`，新增表使用 `_safeCreateTable` 幂等创建，不要直接调用裸 `migrator.addColumn`。

| 目标版本 | 变更 |
| --- | --- |
| 2 | 给 `tasks` 增加 `media_kind` |
| 3 | 增加源文件指纹和基础媒体分析镜像字段 |
| 4 | 增加视频、容器和估算码率字段 |
| 5 | 增加音频码率字段 |
| 6 | 给 `settings` 增加 `default_output_video_codec` |
| 7 | 给 `tasks` 增加 `compression_crf` 和 `output_file_name` |
| 8 | 给 `tasks` 增加 `compression_mode` 和 `target_size_ratio` |
| 9 | 给 `tasks` 增加 `smart_preset` 和 `target_size_bytes` |
| 10 | 给 `settings` 增加保存到源文件旁、默认推荐方案和默认导出文件名模板 |
| 11 | 将 `tasks.compression_mode` 中的历史值 `smart`、`quality` 归一化为 `preset` |
| 12 | 给 `tasks` 增加色彩、像素格式、帧率、宽高比、旋转、场序和音频声道布局镜像字段 |
| 13 | 给 `tasks` 增加 `analysis_audio_stream_index` |
| 14 | 给 `tasks` 增加 `media_config_json` 和图片分析字段；给 `settings` 增加 `default_media_config_json` |
| 15 | 给 `settings` 增加 `theme_mode`，保存浅色 / 深色主题偏好 |
| 16 | 新增 `app_notifications` 表，持久化应用内通知历史 |
| 17 | 给 `app_notifications` 增加 `kind`，支持类型化通知和动作扩展 |
| 18 | 给 `settings` 增加 `hide_notification_badge`，持久化工作台通知角标显隐偏好 |
| 19 | 给 `tasks` 增加 HDR10 静态元数据、色度位置和 Dolby Vision profile / 兼容 ID 分析字段 |
| 20 | 给 `settings` 增加 `task_completion_sound`，持久化任务完成提示音选择 |
| 21 | 给 `settings` 增加 `show_task_completion_dialog`，持久化任务完成后是否弹窗提示 |
| 22 | 将仍停留在旧默认值的设置升级到新默认：推荐方案 `chat`、输出模板 `{source}-{action}`、完成提示音 `clean_success` |
| 23 | 将已停留在 `{source}-{date}` 过渡默认值的设置升级到 `{source}-{action}` |
| 24 | 给 `app_notifications` 增加 `dedupe_key`，并为非空去重键创建唯一索引 |
| 25 | 新增 `task_folders` 表；给 `tasks` 增加 `folder_id`、`folder_sort_order` 和 `policy_tags_json` |
| 26 | 给 `settings` 增加 `max_concurrent_executions`，持久化受控并行执行上限 |
| 27 | 给 `settings` 增加 `folder_import_scan_depth`；给 `tasks` 增加 `analysis_audio_streams_json`；给 `task_folders` 增加 `default_purpose` |
| 28 | 给 `tasks` 增加 `output_file_size`，记录成功完成后的最终输出体积 |
| 29 | 给 `settings` 增加 `notification_policies_json`、`shortcut_bindings_json` 和 `close_behavior`，持久化通知策略、快捷键和关闭行为 |
| 30 | 给 `tasks` 增加 nullable `failure_json`；保留旧错误列并提供旧分析失败、普通失败、损坏 JSON 和未来枚举值的安全兼容读取 |
| 31 | 新增 `engine_analysis_projections`，持久化 FLL Snapshot 与 FEngine session 归属 |
| 32 | 增加 FEngine 分析 / 执行队列、LIFO 恢复栈和进度投影字段，并将旧任务状态迁移到 Engine 状态模型 |
| 33 | 新增 `workbench_order_states`，持久化 Client 对 FEngine 队列 revision 的展示状态 |
| 34 | 为分析和执行投影增加幂等 request ID |
| 35 | 从当前 Settings schema 移除自定义 FFmpeg / FFprobe executable 路径；升级库中残留的旧列不再读取或写入 |

## 修改数据模型的约束

- 新增非空列必须提供 Drift 默认值，或写清楚迁移填充值。
- 枚举持久化值不能随意重命名；确实要重命名时，需要在仓储映射、兼容常量或迁移里兼容旧值。
- 任务状态要能在应用重启后由 FEngine Snapshot 重新校正；不能假设 Client 内存持有执行状态。
- 源文件、预览帧、日志和输出文件路径都是本地路径，跨机器或用户移动文件后可能失效。
- `target_size_ratio` 是兼容字段，新功能应优先读写 `target_size_bytes`。
- 数据库不保存完整 native 探测输出；`engine_analysis_projections.snapshot_json` 保存 FLL 版本化 Snapshot，`tasks` 只保留当前 UI 所需的镜像字段。
