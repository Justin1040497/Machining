# 码率感知压缩策略完成日志

## Behavior Summary

根据飞书白板中的最新流程，新增码率感知压缩策略，并优化现有 FFmpeg 命令构造逻辑。

当前行为：

- FFprobe 分析阶段会保存三个码率字段：
  - `videoBitrate`：优先从 `videoStream.bit_rate` 读取。
  - `containerBitrate`：其次从 `format.bit_rate` 读取。
  - `estimatedBitrate`：如果直接码率字段都没有，则用 `fileSize * 8 / durationSeconds` 估算。
- `MediaAnalysisResult.preferredBitrate` 严格按白板顺序返回有效码率：
  1. `videoBitrate`
  2. `containerBitrate`
  3. `estimatedBitrate`
- 新增 `CompressionAdvisor`，根据分析结果判断视频是否已经高度压缩。
- 命令构造器不再固定使用 `-crf 20`：
  - 普通压缩使用 `CRF 25`。
  - 用户确认后，低码率视频使用极限压缩 `CRF 30`。
- 低码率视频如果未确认，命令构造器会抛出 `CompressionConfirmationRequiredException`。
- 队列执行器遇到该确认异常时，不启动 FFmpeg，也不把任务标记失败，任务保持 `pending`，等待用户确认。
- CLI 会在低码率视频上提示用户“该视频已经压缩过，再压缩体积可能变大”，用户输入 `y` / `yes` 后才使用极限压缩策略。

## Followed Plan Or Flowchart

遵循飞书文档中的相关白板：

- `FFprobe 媒体分析`
  - 增加码率获取阶段。
  - 顺序为 `videoStream.bit_rate` → `format.bit_rate` → `文件大小 / 时长估算`。
- `FFmpeg 命令构造器`
  - 增加压缩策略阶段。
  - 低码率未确认时不直接构造命令。
  - 用户确认后使用更高 CRF。
- `简易CLI - 核心功能测试`
  - 增加低码率提醒、用户确认和极限压缩路径。

## Modified Files

- `lib/domain/value_objects/media_analysis_result.dart`
  - 增加 `videoBitrate`、`containerBitrate`、`estimatedBitrate`。
  - 增加 `preferredBitrate`，按白板顺序选择有效码率。
- `lib/infrastructure/services/ffprobe_media_analyzer.dart`
  - 解析 `videoStream.bit_rate` 和 `format.bit_rate`。
  - 增加通过文件大小和时长估算平均码率。
- `lib/infrastructure/database/tasks.dart`
  - 增加任务分析结果中的三个码率字段。
- `lib/infrastructure/database/app_database.dart`
  - schemaVersion 升级到 4。
  - 增加码率字段迁移。
- `lib/infrastructure/database/app_database.g.dart`
  - 重新生成 Drift 数据库代码。
- `lib/infrastructure/repositories/drift_media_task_repository.dart`
  - 增加码率字段的保存和读取映射。
- `lib/application/services/ffmpeg_command_builder.dart`
  - 增加 `allowExtremeCompression` 参数。
  - 增加 `CompressionConfirmationRequiredException`。
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
  - 接入 `CompressionAdvisor`。
  - 根据压缩建议生成 CRF 参数。
  - 低码率未确认时要求用户确认。
- `lib/application/services/ffmpeg_task_queue_runner.dart`
  - 增加 `compressionConfirmationRequired` 启动结果。
  - 遇到低码率确认异常时保持任务 pending。
- `lib/infrastructure/providers/ffmpeg_provider.dart`
  - 增加 `compressionAdvisorProvider`。
  - 命令构造器 Provider 注入压缩建议服务。
- `tool/machining_cli.dart`
  - 增加低码率提醒和用户确认流程。
  - 用户确认后使用极限压缩。
- `test/ffmpeg_command_builder_test.dart`
  - 更新普通压缩 CRF 预期。
  - 增加低码率确认和极限压缩测试。
- `test/ffmpeg_task_queue_runner_test.dart`
  - 增加低码率需要确认时任务保持 pending 的测试。

## Added Files

- `lib/application/services/compression_advisor.dart`
- `lib/infrastructure/services/default_compression_advisor.dart`
- `test/compression_advisor_test.dart`
- `test/ffprobe_media_analyzer_test.dart`
- `docs/logs/2026-04-29-bitrate-aware-compression-strategy.md`

## Purpose Of Each Added File

- `lib/application/services/compression_advisor.dart`
  - 定义压缩建议服务抽象、压缩档位、码率来源和建议结果。
- `lib/infrastructure/services/default_compression_advisor.dart`
  - 实现第一版码率阈值判断和 CRF 推荐策略。
- `test/compression_advisor_test.dart`
  - 覆盖码率来源优先级、低码率提醒和极限压缩推荐。
- `test/ffprobe_media_analyzer_test.dart`
  - 覆盖 FFprobe 直接码率解析和估算码率。
- `docs/logs/2026-04-29-bitrate-aware-compression-strategy.md`
  - 记录本次服务层能力调整、白板对应关系和验证结果。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 当前阈值仍是第一版经验规则：
  - 1080p 低于 1.5 Mbps 认为高度压缩。
  - 720p 低于 0.8 Mbps 认为高度压缩。
  - 480p 及以下低于 0.5 Mbps 认为高度压缩。
- 当前极限压缩只调整 CRF 到 30，暂未自动降分辨率。
- UI 还没有接入该确认流程；当前 CLI 和队列服务已经具备底层能力。
- 还需要继续用真实视频样片验证：普通码率视频、低码率视频、缺少直接码率字段的视频。

## Validation Method Or Test Result

已运行：

```text
dart run build_runner build --delete-conflicting-outputs
dart format ...
flutter analyze
flutter test
dart run tool/machining_cli.dart --help
dart run tool/machining_cli.dart compress /tmp/not-exist-machining-demo.mp4
```

结果：

```text
No issues found!
All tests passed!
```

说明：

- `flutter test` 当前通过 28 个测试。
- CLI help 顺序执行通过。
- 曾并行执行两个 `dart run` 命令时触发 Dart native assets 对同一个 `.dylib` 的签名竞争；顺序执行后正常。这不是 CLI 业务逻辑失败。
