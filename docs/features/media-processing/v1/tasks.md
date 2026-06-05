# media-processing — 任务清单

基于 `design.md`，列出本次“从视频处理扩展到视频 / 图片 / 音频通用媒体处理”的具体文件级任务。本文档只拆解任务，不实现生产代码或测试代码。

全局约束：
- 必须保留 `MediaTask` 作为统一任务实体，不拆成三套独立任务实体。
- 主领域模型、application 抽象、工作台主入口使用 `Media...` 命名；视频、图片、音频只在分类型实现和分面板中使用 `Video...` / `Image...` / `Audio...`。
- `domain` 层不得依赖 Flutter、Drift、FFmpeg、文件系统或平台 API。
- Drift 首版只新增通用 JSON 配置列和图片分析列，不删除旧 `video_*` 字段。
- 旧视频任务必须能读取，当前视频压缩行为必须先作为回归基线保住。
- 图片首版使用步骤型进度，不伪造基于时长的连续百分比。
- 音频首版不做波形、试听、多轨选择或音频编辑能力。
- 在用户明确说 `可以` 之前，不写生产代码、不写测试代码、不跑实现阶段改动。

状态标记：
- `⬜ 待处理`：尚未开始。
- `🔧 进行中`：实现阶段正在处理。
- `✅ 已完成`：实现、测试和必要文档同步均完成。

## 当前实现切片状态（2026-06-05）

本次已完成首个兼容优先切片，不等同于完整 v1 交付：

- ✅ 已完成：通用配置模型、`MediaTask.config` 主类型泛化、媒体分析字段扩展、Drift schema 14、任务配置 JSON 映射、导入图片 / 音频、FFprobe 纯音频和静态图片解析、FFmpeg 图片 / 音频基础命令计划、步骤型进度、文件选择媒体类型组、通用完成弹窗和关于 / 空态文案。
- 🔧 部分完成：设置表已新增 `default_media_config_json`，但设置仓储和设置 UI 仍以旧视频默认字段为主；缩略图当前视频抽帧、图片源图、音频占位，尚未拆成完整媒体缩略图服务。
- ⬜ 未完成：图片配置面板、音频配置面板、通用配置弹窗拆分、图片 / 音频手动端到端验收、macOS / Windows 发布包级验证、旧视频列长期清理。

---

## 执行顺序

1. ⬜ 任务 1 — 新增通用媒体枚举和值对象命名基础（无依赖）
2. ⬜ 任务 2 — 新增 `MediaTaskConfig` 和分类型配置对象（依赖任务 1）
3. ⬜ 任务 3 — 将 `MediaTask` 主配置从 `VideoTaskConfig` 泛化为 `MediaTaskConfig`（依赖任务 2）
4. ⬜ 任务 4 — 扩展 `MediaAnalysisResult` 为通用分析结果（依赖任务 1）
5. ⬜ 任务 5 — 泛化应用设置模型和默认处理配置（依赖任务 2）
6. ⬜ 任务 6 — 改造媒体导入与初始配置 helper（依赖任务 2、5）
7. ⬜ 任务 7 — 改造导入、重新指定源文件和分析 use case（依赖任务 3、4、6）
8. ⬜ 任务 8 — 新增或重命名 application 媒体处理抽象（依赖任务 2、4）
9. ⬜ 任务 9 — Drift schema 14 迁移和表字段扩展（依赖任务 2、4、5）
10. ⬜ 任务 10 — 仓储配置 JSON 映射和旧视频列兼容读取（依赖任务 9）
11. ⬜ 任务 11 — 设置仓储默认媒体配置读写兼容（依赖任务 5、9）
12. ⬜ 任务 12 — FFprobe 分析器支持视频、图片、音频（依赖任务 4、7）
13. ⬜ 任务 13 — FFmpeg 命令规划改为按 `MediaKind` 分派（依赖任务 2、8、12）
14. ⬜ 任务 14 — 执行进度支持 `timed` 和 `step` 两种模式（依赖任务 8、13）
15. ⬜ 任务 15 — 缩略图与预览服务泛化为媒体服务（依赖任务 8、12）
16. ⬜ 任务 16 — 工作台文件选择和拖拽入口支持媒体类型组（依赖任务 6）
17. ⬜ 任务 17 — 工作台导入失败、空态、顶部和关于文案泛化（依赖任务 16）
18. ⬜ 任务 18 — 配置弹窗拆成通用外壳和三类分面板（依赖任务 2、3）
19. ⬜ 任务 19 — 工作台配置策略、格式化和展示 mapper 泛化（依赖任务 18）
20. ⬜ 任务 20 — 任务列表缩略图、完成弹窗和输出信息泛化（依赖任务 15、19）
21. ⬜ 任务 21 — 更新 provider / notifier 注入和状态流命名（依赖任务 8、10、13、15、20）
22. ⬜ 任务 22 — Domain 和 settings 测试覆盖新配置模型（依赖任务 1 到 5）
23. ⬜ 任务 23 — Use case 测试覆盖导入、重连源文件和分析路径（依赖任务 6、7、12）
24. ⬜ 任务 24 — Drift 仓储测试覆盖新旧配置兼容和 schema 迁移（依赖任务 9 到 11）
25. ⬜ 任务 25 — FFprobe、FFmpeg 规划和进度测试覆盖三类媒体（依赖任务 12 到 14）
26. ⬜ 任务 26 — Workbench widget 测试覆盖导入、配置、列表和完成弹窗（依赖任务 16 到 21）
27. ⬜ 任务 27 — 同步开发文档和产品文档（依赖任务 1 到 26）
28. ⬜ 任务 28 — 执行格式化、代码生成、静态分析和测试验证（依赖任务 1 到 27）

---

## 任务 1：通用媒体枚举和值对象命名基础 `⬜ 待处理`

**文件：**
- `lib/domain/enums/media_output_format.dart`
- `lib/domain/enums/image_codec.dart`
- `lib/domain/enums/audio_codec.dart`
- `lib/domain/enums/media_processing_preset.dart`
- `lib/domain/enums/output_format.dart`
- `lib/domain/enums/smart_compression_preset.dart`

**类型：** 新建 / 修改

### 1.1 新增通用输出格式枚举 `⬜`

骨架：

```dart
enum MediaOutputFormat {
  mp4,
  mov,
  mkv,
  jpg,
  png,
  webp,
  mp3,
  m4a,
  aac,
  wav,
  flac,
}
```

约束：
- `MediaOutputFormat` 是通用配置入口，不应携带 UI 文案。
- 需要提供按 `MediaKind` 过滤可用格式的纯 domain helper。
- 旧 `OutputFormat` 在兼容期只作为视频旧字段适配来源，不继续作为主配置类型。

### 1.2 新增图片和音频编码枚举 `⬜`

骨架：

```dart
enum ImageCodec { source, jpeg, png, webp }
enum AudioCodec { source, aac, mp3, opus, flac, pcm }
```

约束：
- 不把图片 / 音频编码塞进 `VideoCodec`。
- `source` 表示尽量保留源编码或源格式，具体实现由 infrastructure 决定。

### 1.3 泛化处理预设命名 `⬜`

骨架：

```dart
enum MediaProcessingPreset {
  sourceLike,
  balanced,
  smaller,
  smallest,
}
```

约束：
- 现有 `SmartCompressionPreset` 不能继续作为图片 / 音频主预设名。
- 视频旧预设需要在兼容层映射到新预设或保留为视频内部策略。

---

## 任务 2：`MediaTaskConfig` 和分类型配置对象 `⬜ 待处理`

**文件：**
- `lib/domain/value_objects/media_task_config.dart`
- `lib/domain/value_objects/video_processing_config.dart`
- `lib/domain/value_objects/image_processing_config.dart`
- `lib/domain/value_objects/audio_processing_config.dart`
- `lib/domain/value_objects/video_task_config.dart`

**类型：** 新建 / 修改

### 2.1 新增 `MediaTaskConfig` `⬜`

骨架：

```dart
class MediaTaskConfig {
  const MediaTaskConfig({
    required this.outputDirectory,
    required this.outputFileName,
    required this.compressionMode,
    this.preset,
    this.targetSizeBytes,
    this.targetSizeRatio,
    this.video,
    this.image,
    this.audio,
  });

  final String outputDirectory;
  final String outputFileName;
  final CompressionMode compressionMode;
  final MediaProcessingPreset? preset;
  final int? targetSizeBytes;
  final double? targetSizeRatio;
  final VideoProcessingConfig? video;
  final ImageProcessingConfig? image;
  final AudioProcessingConfig? audio;
}
```

约束：
- 通用字段放在 `MediaTaskConfig`。
- 视频、图片、音频差异字段只放在对应分类型配置。
- 提供 `copyWith`、等值比较和必要的类型选择 helper。

### 2.2 新增视频配置对象 `⬜`

骨架：

```dart
class VideoProcessingConfig {
  final MediaOutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final int crf;
}
```

约束：
- 字段从现有 `VideoTaskConfig` 迁移，不改变默认视频行为。
- 原 `VideoTaskConfig` 只保留为兼容 adapter 或迁移来源，不能继续作为 `MediaTask.config` 类型。

### 2.3 新增图片配置对象 `⬜`

骨架：

```dart
class ImageProcessingConfig {
  final MediaOutputFormat outputFormat;
  final ImageCodec imageCodec;
  final int imageQuality;
  final ImageResizePreset resizePreset;
  final bool preserveMetadata;
}
```

约束：
- `imageQuality` 范围为 1 到 100。
- `preserveMetadata` 首版默认 `false`。
- 自定义尺寸如未在设计确认，不在首版扩大范围。

### 2.4 新增音频配置对象 `⬜`

骨架：

```dart
class AudioProcessingConfig {
  final MediaOutputFormat outputFormat;
  final AudioCodec audioCodec;
  final AudioBitratePreset bitratePreset;
  final AudioSampleRatePreset sampleRate;
  final AudioChannelsPreset channels;
}
```

约束：
- 首版只做格式、编码、码率、采样率、声道。
- 不加入裁剪、音量、淡入淡出、波形相关字段。

---

## 任务 3：`MediaTask` 主实体配置泛化 `⬜ 待处理`

**文件：**
- `lib/domain/entities/media_task.dart`

**类型：** 修改

### 3.1 替换主配置类型 `⬜`

骨架：

```dart
class MediaTask {
  final MediaKind mediaKind;
  final MediaTaskConfig config;
}
```

约束：
- `MediaTask.config` 不再引用 `VideoTaskConfig`。
- `MediaTask.draft` 接收 `MediaTaskConfig?`。
- 视频旧默认配置通过 helper 生成，不在实体中写 infrastructure 逻辑。

### 3.2 增加按媒体类型校验的 domain 不变量 `⬜`

骨架：

```dart
void validateConfigForKind() {
  switch (mediaKind) {
    case MediaKind.video:
      // 要求 config.video != null
    case MediaKind.image:
      // 要求 config.image != null
    case MediaKind.audio:
      // 要求 config.audio != null
  }
}
```

约束：
- 校验只关心 domain 对象完整性。
- 不在 domain 中检查文件存在、FFmpeg 支持或平台能力。

---

## 任务 4：`MediaAnalysisResult` 通用分析结果 `⬜ 待处理`

**文件：**
- `lib/domain/value_objects/media_analysis_result.dart`

**类型：** 修改

### 4.1 补齐图片字段 `⬜`

骨架字段：

```dart
final int? imageWidth;
final int? imageHeight;
final String? imageCodec;
final String? imagePixelFormat;
final int? imageBitDepth;
final int? orientationDegrees;
```

约束：
- 纯图片可没有 `durationMs`。
- 纯音频可没有视频宽高。
- 旧视频字段继续保留，避免一次性破坏现有 UI 和估算逻辑。

### 4.2 梳理通用字段语义 `⬜`

需要确认的字段：
- `durationMs`
- `containerFormat`
- `containerBitrate`
- `estimatedBitrate`
- `fileSizeBytes`

约束：
- `estimatedBitrate` 对图片可为空。
- 仓储和 UI 不应假设所有任务都有 duration。

---

## 任务 5：应用设置模型泛化 `⬜ 待处理`

**文件：**
- `lib/domain/entities/app_settings.dart`
- `lib/application/repositories/app_settings_repository.dart`
- `lib/application/use_cases/app_settings/load_app_settings_use_case.dart`
- `lib/application/use_cases/app_settings/save_app_settings_use_case.dart`

**类型：** 修改

### 5.1 将默认压缩设置泛化为默认媒体处理设置 `⬜`

骨架：

```dart
class AppMediaProcessingSettings {
  final MediaTaskConfig defaultVideoConfig;
  final MediaTaskConfig defaultImageConfig;
  final MediaTaskConfig defaultAudioConfig;
}
```

约束：
- 旧 `AppCompressionSettings` 可以保留兼容 getter，但不继续作为新 UI 主名称。
- 默认配置不得依赖 UI 控件。

### 5.2 保持旧设置读取兼容 `⬜`

逻辑步骤：
1. 优先读取新默认媒体配置。
2. 如果不存在，使用旧视频默认字段构造 `defaultVideoConfig`。
3. 图片和音频使用 domain 默认值。

---

## 任务 6：媒体导入 helper 和初始配置构造 `⬜ 待处理`

**文件：**
- `lib/application/use_cases/media_tasks/media_task_use_case_helpers.dart`

**类型：** 修改

### 6.1 替换视频专用支持校验 `⬜`

当前需要改造的行为：
- `ensureSupportedImportedMediaKind` 不能继续拒绝 `MediaKind.image` 和 `MediaKind.audio`。

目标骨架：

```dart
void ensureSupportedImportedMediaKind(MediaKind kind) {
  switch (kind) {
    case MediaKind.video:
    case MediaKind.image:
    case MediaKind.audio:
      return;
  }
}
```

约束：
- 不支持扩展名仍由 `MediaKindResolver` 抛错。
- 文件夹导入仍在 UI / input 层拒绝。

### 6.2 构造三类初始配置 `⬜`

目标骨架：

```dart
MediaTaskConfig buildInitialMediaTaskConfigFromSettings({
  required MediaKind mediaKind,
  required AppSettings settings,
  required String sourcePath,
});
```

约束：
- 输出目录、输出文件名生成仍复用现有规则。
- 视频默认值必须与当前 `VideoTaskConfig` 行为一致。

---

## 任务 7：导入、重新指定源文件和分析 use case `⬜ 待处理`

**文件：**
- `lib/application/use_cases/media_tasks/import_media_task_use_case.dart`
- `lib/application/use_cases/media_tasks/replace_missing_source_use_case.dart`
- `lib/application/use_cases/media_tasks/analyze_media_task_use_case.dart`
- `lib/application/use_cases/media_tasks/retry_media_task_use_case.dart`

**类型：** 修改

### 7.1 导入流程接收三类媒体 `⬜`

逻辑步骤：
1. 解析源文件为 `MediaKind`。
2. 构造对应 `MediaTaskConfig`。
3. 创建 `MediaTask.draft`。
4. 写入 analyzing / pending 状态。

约束：
- 不能仅放开扩展名而让 FFprobe 或 FFmpeg 深层失败。
- 失败错误需要保留可展示的用户原因。

### 7.2 重新指定源文件保持媒体类型一致 `⬜`

逻辑步骤：
- `newMediaKind == task.mediaKind` 才允许替换。
- 替换后重新分析并保留任务配置。

### 7.3 重试和重新分析处理缺失 duration 的媒体 `⬜`

约束：
- 图片任务不能因为 `durationMs == null` 无法进入 pending。
- 音频任务可使用 duration 但不能要求视频流存在。

---

## 任务 8：Application 媒体处理抽象 `⬜ 待处理`

**文件：**
- `lib/application/services/ffmpeg_planning/ffmpeg_command_builder.dart`
- `lib/application/services/ffmpeg_planning/compression_advisor.dart`
- `lib/application/services/ffmpeg_planning/compression_estimator.dart`
- `lib/application/services/execution/video_thumbnail_generator.dart`
- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`

**类型：** 修改 / 新建

### 8.1 命令构造抽象改为媒体语义 `⬜`

建议新建或重命名：

```text
lib/application/services/ffmpeg_planning/media_command_builder.dart
lib/application/services/ffmpeg_planning/media_processing_advisor.dart
lib/application/services/ffmpeg_planning/media_processing_estimator.dart
```

骨架：

```dart
abstract interface class MediaCommandBuilder {
  Future<FfmpegCommandPlan> build(MediaTask task);
}
```

约束：
- `FfmpegCommandPlan` 可以保留 FFmpeg 名称，因为当前执行实现仍是 FFmpeg。
- application 抽象不暴露 `VideoTaskConfig`。

### 8.2 缩略图和预览抽象改为媒体语义 `⬜`

建议新建或重命名：

```text
lib/application/services/execution/media_thumbnail_generator.dart
lib/application/services/execution/media_preview_generator.dart
lib/application/services/execution/media_task_queue_runner.dart
```

约束：
- 若短期保留 `FfmpegTaskQueueRunner`，它应作为 FFmpeg 实现细节，不作为 UI 主语义。
- 音频首版只要求稳定占位缩略图，不要求波形。

---

## 任务 9：Drift schema 14 和表字段扩展 `⬜ 待处理`

**文件：**
- `lib/infrastructure/database/tasks.dart`
- `lib/infrastructure/database/settings.dart`
- `lib/infrastructure/database/app_database.dart`
- `lib/infrastructure/database/app_database.g.dart`

**类型：** 修改 / 生成

### 9.1 `tasks` 表新增通用配置和图片分析列 `⬜`

字段骨架：

```dart
TextColumn get mediaConfigJson => text().nullable()();
IntColumn get analysisImageWidth => integer().nullable()();
IntColumn get analysisImageHeight => integer().nullable()();
TextColumn get analysisImageCodec => text().nullable()();
TextColumn get analysisImagePixelFormat => text().nullable()();
IntColumn get analysisImageBitDepth => integer().nullable()();
```

约束：
- 不删除旧 `video_*` 列。
- 迁移脚本必须允许旧数据库升级。

### 9.2 `settings` 表新增默认媒体配置 `⬜`

字段骨架：

```dart
TextColumn get defaultMediaConfigJson => text().nullable()();
```

约束：
- 旧 `default_output_video_codec` 等字段继续保留。
- 读取优先级由仓储处理。

### 9.3 `AppDatabase.schemaVersion` 升到 14 `⬜`

迁移步骤骨架：

```dart
if (from < 14) {
  await migrator.addColumn(tasks, tasks.mediaConfigJson);
  // 图片分析列
  // settings 默认媒体配置列
}
```

约束：
- `app_database.g.dart` 只通过 `dart run build_runner build --delete-conflicting-outputs` 生成，不手写。

---

## 任务 10：任务仓储配置 JSON 映射与兼容读取 `⬜ 待处理`

**文件：**
- `lib/infrastructure/repositories/drift_media_task_repository.dart`

**类型：** 修改

### 10.1 新增 `MediaTaskConfig` JSON mapper `⬜`

骨架：

```dart
Map<String, Object?> mediaTaskConfigToJson(MediaTaskConfig config);
MediaTaskConfig mediaTaskConfigFromJson(Map<String, Object?> json);
```

约束：
- JSON 内包含版本号，例如 `schemaVersion` 或 `configVersion`。
- 枚举序列化使用稳定字符串，不使用 index。

### 10.2 旧视频列 fallback `⬜`

读取规则：
1. `media_config_json` 存在时优先读取。
2. 不存在时从旧视频列构造 `MediaTaskConfig.video`。
3. 保存时写入 `media_config_json`，兼容期继续写旧视频列。

### 10.3 图片分析列映射 `⬜`

约束：
- `MediaAnalysisResult` 的图片字段写入新列。
- 旧视频 / 音频分析字段保持现有映射。

---

## 任务 11：设置仓储默认媒体配置兼容 `⬜ 待处理`

**文件：**
- `lib/infrastructure/repositories/drift_app_settings_repository.dart`

**类型：** 修改

### 11.1 读取 `default_media_config_json` `⬜`

逻辑步骤：
1. 如果有新 JSON，解析为默认媒体配置。
2. 如果没有，使用旧视频字段生成视频默认配置。
3. 图片 / 音频默认配置使用 domain 默认值。

### 11.2 保存时写新字段并保留旧字段 `⬜`

约束：
- 视频旧字段继续写入，减少回滚风险。
- 新默认配置 mapper 应与任务配置 mapper 共享稳定枚举序列化规则。

---

## 任务 12：`FfprobeMediaAnalyzer` 支持三类媒体 `⬜ 待处理`

**文件：**
- `lib/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart`

**类型：** 修改

### 12.1 解析时不再要求视频流必然存在 `⬜`

目标逻辑：
- 视频：优先解析视频流，附带主音频流信息。
- 图片：解析图片流宽高、像素格式、编码和 format 信息。
- 音频：解析音频流 duration、codec、bitrate、channels、sample rate。

### 12.2 允许部分分析结果 `⬜`

约束：
- 图片文件即使缺少 duration，也可以返回可用的 `MediaAnalysisResult`。
- FFprobe 异常仍要转换为当前 application 可处理的分析失败错误。

---

## 任务 13：FFmpeg 命令规划按 `MediaKind` 分派 `⬜ 待处理`

**文件：**
- `lib/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart`
- `lib/infrastructure/services/ffmpeg_planning/default_media_command_builder.dart`
- `lib/infrastructure/services/ffmpeg_planning/video_command_planner.dart`
- `lib/infrastructure/services/ffmpeg_planning/image_command_planner.dart`
- `lib/infrastructure/services/ffmpeg_planning/audio_command_planner.dart`
- `lib/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart`
- `lib/infrastructure/services/ffmpeg_planning/ffmpeg_encoder_resolver.dart`
- `lib/infrastructure/services/ffmpeg_planning/ffmpeg_command_step_builder.dart`

**类型：** 修改 / 新建

### 13.1 新增分派型 command builder `⬜`

骨架：

```dart
class DefaultMediaCommandBuilder implements MediaCommandBuilder {
  Future<FfmpegCommandPlan> build(MediaTask task) {
    switch (task.mediaKind) {
      case MediaKind.video:
        // VideoCommandPlanner
      case MediaKind.image:
        // ImageCommandPlanner
      case MediaKind.audio:
        // AudioCommandPlanner
    }
  }
}
```

### 13.2 保留视频规划回归行为 `⬜`

约束：
- 两遍目标体积、硬件编码、HDR 降级、主音频流选择、`-movflags +faststart` 不回退。
- 当前视频命令测试应先迁移为回归测试。

### 13.3 新增图片命令规划 `⬜`

骨架规则：
- JPEG / WebP 使用质量参数。
- PNG 使用无损或压缩级别参数。
- 尺寸调整使用长边限制并保持宽高比。
- `progressMode` 使用 `ProgressMode.step`。

### 13.4 新增音频命令规划 `⬜`

骨架规则：
- 使用 `-vn` 禁用视频流。
- 按配置设置 `-c:a`、`-b:a`、`-ar`、`-ac`。
- 有 duration 时使用 `ProgressMode.timed`。

---

## 任务 14：执行进度模式 `⬜ 待处理`

**文件：**
- `lib/application/services/ffmpeg_planning/ffmpeg_command_builder.dart`
- `lib/application/services/execution/ffmpeg_process_observer.dart`
- `lib/infrastructure/services/execution/local_ffmpeg_process_observer.dart`
- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`

**类型：** 修改

### 14.1 新增 `ProgressMode` `⬜`

骨架：

```dart
enum ProgressMode { timed, step }

class FfmpegCommandStep {
  final ProgressMode progressMode;
}
```

### 14.2 `LocalFfmpegProcessObserver` 处理步骤进度 `⬜`

逻辑步骤：
- `timed` 继续使用 `out_time_ms / duration`。
- `step` 在步骤开始、步骤完成时推进，不要求 FFmpeg 输出时长。
- 完成和失败仍由退出码和输出文件校验决定。

---

## 任务 15：媒体缩略图与预览服务 `⬜ 待处理`

**文件：**
- `lib/application/services/execution/video_thumbnail_generator.dart`
- `lib/application/services/execution/media_thumbnail_generator.dart`
- `lib/infrastructure/services/execution/local_video_thumbnail_generator.dart`
- `lib/infrastructure/services/execution/local_media_thumbnail_generator.dart`
- `lib/infrastructure/services/execution/local_image_thumbnail_generator.dart`
- `lib/infrastructure/services/execution/local_audio_thumbnail_generator.dart`
- `lib/infrastructure/providers/execution_provider.dart`

**类型：** 修改 / 新建

### 15.1 新增 `MediaThumbnailGenerator` 抽象 `⬜`

骨架：

```dart
abstract interface class MediaThumbnailGenerator {
  Future<MediaThumbnailResult> generate(MediaTask task);
}
```

### 15.2 三类缩略图策略 `⬜`

策略：
- 视频：复用非黑帧抽取逻辑。
- 图片：源图直接显示或生成小尺寸缓存。
- 音频：返回稳定类型占位图和文件信息。

约束：
- 首版不做音频波形。
- 旧 `VideoThumbnailGenerator` 可作为视频实现内部类或兼容 adapter。

---

## 任务 16：工作台文件选择和拖拽入口 `⬜ 待处理`

**文件：**
- `lib/features/workbench/pages/workbench_page/configuration/workbench_constants.dart`
- `lib/features/workbench/pages/workbench_page/workbench_file_picker.dart`
- `lib/features/workbench/pages/workbench_page/workbench_import_handler.dart`

**类型：** 修改

### 16.1 文件类型组从视频改为媒体 `⬜`

目标命名：
- `videoTypeGroup` 拆为 `mediaTypeGroups` 或 `videoTypeGroup` / `imageTypeGroup` / `audioTypeGroup`。
- `pickVideoFiles()` 改为 `pickMediaFiles()`。

约束：
- 文件夹仍拒绝。
- 选择器应支持视频、图片、音频扩展名。

### 16.2 导入失败提示泛化 `⬜`

文案方向：
- “只能导入视频文件”改为“只能导入支持的媒体文件”。
- 文件夹提示改为“只能导入媒体文件，不能导入文件夹”。

---

## 任务 17：工作台用户可见文案泛化 `⬜ 待处理`

**文件：**
- `lib/features/workbench/pages/workbench_page/layout/task_list_card.dart`
- `lib/features/workbench/pages/workbench_page/layout/top_bar.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/import_failure_dialog.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart`

**类型：** 修改

### 17.1 空态和动作文案从视频改为媒体 `⬜`

检查点：
- “添加视频”改为“添加媒体”或按上下文使用“添加文件”。
- 关于弹窗从“视频压缩工具”改为“本地媒体处理工具”。

约束：
- 不把功能说明写成营销页。
- 文案必须与首版能力一致，不能暗示已支持音频编辑或波形预览。

---

## 任务 18：配置弹窗通用外壳和分类型面板 `⬜ 待处理`

**文件：**
- `lib/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/media_config_panel.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/video_config_panel.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/image_config_panel.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/audio_config_panel.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart`

**类型：** 修改 / 新建

### 18.1 新增通用媒体配置面板 `⬜`

骨架：

```dart
class WorkbenchMediaConfigPanel extends StatelessWidget {
  final MediaTask task;
  final MediaTaskConfig draft;
}
```

分派规则：
- `MediaKind.video` 显示 `WorkbenchVideoConfigPanel`。
- `MediaKind.image` 显示 `WorkbenchImageConfigPanel`。
- `MediaKind.audio` 显示 `WorkbenchAudioConfigPanel`。

### 18.2 视频面板降级为分类型面板 `⬜`

约束：
- 当前视频控件和推荐预设不回退。
- 面板输入输出使用 `VideoProcessingConfig`，不再直接改 `VideoTaskConfig`。

### 18.3 新增图片和音频面板骨架 `⬜`

图片控件：
- 输出格式。
- 图片质量。
- 尺寸预设。
- 是否保留元数据。

音频控件：
- 输出格式。
- 音频编码。
- 码率。
- 采样率。
- 声道。

---

## 任务 19：Workbench 配置策略和展示 mapper `⬜ 待处理`

**文件：**
- `lib/features/workbench/pages/workbench_page/configuration/workbench_policies.dart`
- `lib/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart`
- `lib/features/workbench/pages/workbench_page/configuration/workbench_models.dart`
- `lib/features/workbench/presentation_mappers/domain_labels.dart`

**类型：** 修改

### 19.1 `MediaTaskAdjustmentPolicy` 按媒体类型比较 `⬜`

目标：
- 视频：保持当前压缩参数比较逻辑。
- 图片：比较格式、质量、尺寸、元数据设置。
- 音频：比较格式、编码、码率、采样率、声道。

### 19.2 展示 label 和格式化支持三类媒体 `⬜`

约束：
- domain enum 不直接携带 UI 文案。
- UI mapper 负责中文 label、单位和摘要。

---

## 任务 20：任务列表缩略图和完成弹窗泛化 `⬜ 待处理`

**文件：**
- `lib/features/workbench/pages/workbench_page/workbench_task_thumbnail_store.dart`
- `lib/features/workbench/widgets/media_task_list/media_task_thumbnail.dart`
- `lib/features/workbench/widgets/media_task_list/media_task_list_tile.dart`
- `lib/features/workbench/widgets/media_task_list/media_task_list_item_models.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/compression_confirmation_dialog.dart`

**类型：** 修改

### 20.1 缩略图状态支持三类媒体 `⬜`

约束：
- 视频继续显示抽帧。
- 图片显示图片缩略图。
- 音频显示稳定占位和媒体类型信息。

### 20.2 完成弹窗文案改为通用处理结果 `⬜`

目标：
- “压缩完成”改为“处理完成”或按任务 purpose 显示。
- “压缩前 / 压缩后”改为“源文件 / 输出文件”。
- 保留打开输出文件和打开所在位置能力。

---

## 任务 21：Provider / notifier 注入和主链路命名收敛 `⬜ 待处理`

**文件：**
- `lib/infrastructure/providers/ffmpeg_planning_provider.dart`
- `lib/infrastructure/providers/execution_provider.dart`
- `lib/features/workbench/providers/media_task_notifier.dart`
- `lib/features/workbench/providers/workbench_preview_notifier.dart`
- `lib/features/workbench/pages/workbench_page.dart`

**类型：** 修改

### 21.1 将注入从视频服务切到媒体服务 `⬜`

检查点：
- command builder provider 暴露 `MediaCommandBuilder`。
- thumbnail provider 暴露 `MediaThumbnailGenerator`。
- notifier 不再依赖视频专用配置类型。

### 21.2 保持现有工作台状态流稳定 `⬜`

约束：
- 不引入新的全局状态管理方案。
- 继续复用当前任务队列、通知和错误展示模式。

---

## 任务 22：Domain 和 settings 测试 `⬜ 待处理`

**文件：**
- `test/media_task_config_test.dart`
- `test/app_settings_test.dart`
- `test/app_settings_use_cases_test.dart`

**类型：** 测试

### 22.1 `MediaTaskConfig` 不变量测试 `⬜`

覆盖：
- video task 必须有 video config。
- image task 必须有 image config。
- audio task 必须有 audio config。
- 旧视频默认值映射到新配置后不变。

### 22.2 settings 默认配置兼容测试 `⬜`

覆盖：
- 旧设置字段能生成默认视频配置。
- 新默认媒体配置优先。
- 图片 / 音频默认配置稳定。

---

## 任务 23：Use case 测试 `⬜ 待处理`

**文件：**
- `test/media_task_execution_use_cases_test.dart`
- `test/media_task_notifier_test.dart`
- 新增 `test/import_media_task_use_case_test.dart`，如现有测试结构需要

**类型：** 测试

### 23.1 导入三类媒体 `⬜`

覆盖：
- 视频导入保持旧行为。
- 图片导入不会被 import 阶段拒绝。
- 音频导入不会被 import 阶段拒绝。
- 不支持扩展名仍失败。

### 23.2 重新指定源文件媒体类型一致性 `⬜`

覆盖：
- 视频不能替换为音频。
- 图片不能替换为视频。
- 同类型替换后重新进入分析流程。

---

## 任务 24：Drift 仓储和迁移测试 `⬜ 待处理`

**文件：**
- `test/drift_media_task_repository_test.dart`
- `test/drift_app_settings_repository_test.dart`

**类型：** 测试

### 24.1 新配置 JSON 读写测试 `⬜`

覆盖：
- 视频、图片、音频配置可保存并读回。
- 枚举使用稳定字符串。
- 图片分析字段可保存并读回。

### 24.2 旧视频列 fallback 测试 `⬜`

覆盖：
- 没有 `media_config_json` 的旧任务能构造 `MediaTaskConfig.video`。
- 保存新任务时兼容期继续写旧视频列。
- schema 13 到 14 迁移不丢旧数据。

---

## 任务 25：FFprobe、FFmpeg 和进度测试 `⬜ 待处理`

**文件：**
- `test/ffprobe_media_analyzer_test.dart`
- `test/ffmpeg_command_builder_test.dart`
- `test/ffmpeg_process_observer_test.dart`
- `test/ffmpeg_task_queue_runner_test.dart`

**类型：** 测试

### 25.1 FFprobe 三类样例 `⬜`

覆盖：
- 视频样例保持当前结果。
- 纯音频样例不要求视频流。
- 静态图片样例可得到宽高或部分分析结果。

### 25.2 FFmpeg 命令规划三类媒体 `⬜`

覆盖：
- 视频命令参数回归。
- 图片命令包含格式、质量、尺寸参数。
- 音频命令包含 `-vn`、`-c:a`、`-b:a`、`-ar`、`-ac`。

### 25.3 进度模式测试 `⬜`

覆盖：
- `ProgressMode.timed` 使用 duration。
- `ProgressMode.step` 不依赖 `out_time_ms`。
- 图片任务不会因缺少 duration 卡住。

---

## 任务 26：Workbench widget 测试 `⬜ 待处理`

**文件：**
- `test/widget_test.dart`
- `test/workbench_about_dialog_test.dart`
- `test/app_settings_dialog_test.dart`
- `test/workbench_bottom_bar_test.dart`
- 新增或扩展配置弹窗 widget 测试

**类型：** 测试

### 26.1 文件选择和导入 UI 测试 `⬜`

覆盖：
- 文件选择器暴露媒体类型组。
- 导入失败文案不再只说视频。
- 空态和主动作使用通用媒体文案。

### 26.2 配置弹窗三类面板测试 `⬜`

覆盖：
- 视频任务显示视频配置面板。
- 图片任务显示图片配置面板。
- 音频任务显示音频配置面板。

### 26.3 完成弹窗和缩略图测试 `⬜`

覆盖：
- 完成弹窗使用“源文件 / 输出文件”。
- 视频、图片、音频缩略图状态都有稳定 fallback。

---

## 任务 27：文档同步 `⬜ 待处理`

**文件：**
- `docs/README.md`
- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/test-plan.md`
- `docs/develop/technology-stack.md`
- `docs/product/roadmap.md`
- `docs/features/media-processing/v1/design.md`

**类型：** 文档

### 27.1 更新产品定位和架构描述 `⬜`

同步内容：
- 从“视频压缩”更新为“本地媒体处理”。
- 说明 `MediaTask`、`MediaTaskConfig`、分类型配置和三类媒体边界。
- 明确当前仍主要验证 macOS Apple Silicon 和 Windows x64。

### 27.2 更新数据模型和 schema version `⬜`

同步内容：
- `schemaVersion` 更新到实现后的版本。
- 记录 `media_config_json`、图片分析列、旧 `video_*` 列兼容规则。
- 修正 `technology-stack.md` 中 schema version 滞后问题。

### 27.3 更新测试计划和路线图 `⬜`

同步内容：
- 增加图片 / 音频导入、分析、命令、进度、UI 测试范围。
- 根据实现完成度更新 `roadmap` 状态。

---

## 任务 28：验证路径 `⬜ 待处理`

**文件：**
- 全部被修改的 Dart、Drift 生成文件、测试和文档

**类型：** 验证

### 28.1 代码生成和格式化 `⬜`

实现阶段 Drift 改动后执行：

```bash
dart run build_runner build --delete-conflicting-outputs
git ls-files '*.dart' | xargs dart format --set-exit-if-changed
```

### 28.2 静态分析和测试 `⬜`

实现阶段执行：

```bash
flutter analyze
flutter test
```

### 28.3 手动验收 `⬜`

验收清单：
- 旧视频任务可读取并正常处理。
- 视频导入、分析、配置、执行、完成弹窗不回退。
- 图片导入、分析、配置、执行和输出路径可用。
- 音频导入、分析、配置、执行和输出路径可用。
- 图片任务进度不因缺少 duration 卡住。
- 音频任务输出不包含视频流。

---

## 暂不实现

| 功能 | 本轮不做的原因 |
| --- | --- |
| 文件夹递归批量导入 | 涉及过滤、重复、权限、失败汇总和大量任务性能 |
| GIF 动图专门优化 | GIF 可能是图片也可能类似视频，压缩策略复杂 |
| 图片 EXIF 编辑或水印 | 超出压缩 / 转换主线 |
| 音频裁剪、淡入淡出、音量标准化 | 属于音频编辑能力 |
| 音频波形预览和试听对比 | 需要额外缓存、渲染和播放器交互 |
| 多音轨选择和字幕处理 | 会显著扩大当前视频主链路范围 |
| 新增后端服务或云端处理 | 当前产品是本地 Flutter 桌面应用 |
| 立即删除旧 `video_*` 数据库列 | 增加历史数据迁移和回滚风险 |
| Linux / Web 发布级支持 | 当前主要验证平台仍是 macOS Apple Silicon 和 Windows x64 |
