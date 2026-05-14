# 目标码率极限压缩策略完成日志

## Behavior Summary

根据真实视频测试结果，修正低码率视频的极限压缩策略。

上一版低码率确认后只把 CRF 调整到 30，但真实测试发现仍可能让文件变大。原因是 CRF 不控制目标体积，且音频固定 192k 会让本来低码率的视频变大。

本次调整后：

- 低码率视频仍会先提醒用户确认。
- 用户确认继续压缩后，不再只使用 `CRF 30`。
- 极限压缩改为目标码率策略：
  - 目标总码率低于原视频码率。
  - 降低音频码率，默认目标为 64k。
  - 根据目标总码率和目标音频码率计算目标视频码率。
  - FFmpeg 参数使用 `-b:v`、`-maxrate`、`-bufsize` 限制视频码率。
- 按用户要求，极限压缩不会自动降低分辨率。
- 只有当用户任务配置明确选择非原始分辨率时，命令构造器才会追加 scale 参数。

## Followed Plan Or Flowchart

已更新并遵循飞书白板：

- `FFmpeg 命令构造器`
  - 极限压缩策略从 `CRF 30` 改为目标码率策略。
  - 明确写入“不自动追加 scale / 保持原始分辨率”。
  - 只响应用户明确配置的分辨率变化。
- `简易CLI - 核心功能测试`
  - 低码率确认后显示“目标码率 + 降音频 / 不降低分辨率”。

## Modified Files

- `lib/domain/value_objects/media_analysis_result.dart`
  - 新增 `audioBitrate`，用于极限压缩时判断音频码率。
- `lib/application/services/compression_advisor.dart`
  - 扩展 `CompressionRecommendation`，新增 `targetTotalBitrate`、`targetVideoBitrate`、`targetAudioBitrate`。
- `lib/infrastructure/services/default_compression_advisor.dart`
  - 极限压缩策略改为计算目标总码率、目标视频码率和目标音频码率。
- `lib/infrastructure/services/ffprobe_media_analyzer.dart`
  - 从 `audioStream.bit_rate` 解析 `audioBitrate`。
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
  - 极限压缩时生成 `-b:v`、`-maxrate`、`-bufsize` 和更低的 `-b:a`。
  - 极限压缩不自动降低分辨率。
- `lib/infrastructure/database/tasks.dart`
  - 增加 `analysis_audio_bitrate` 字段。
- `lib/infrastructure/database/app_database.dart`
  - schemaVersion 升级到 5，并增加音频码率字段迁移。
- `lib/infrastructure/database/app_database.g.dart`
  - 重新生成 Drift 数据库代码。
- `lib/infrastructure/repositories/drift_media_task_repository.dart`
  - 增加音频码率字段映射。
- `tool/machining_cli.dart`
  - 用户确认极限压缩后，打印目标总码率、目标视频码率、目标音频码率，并说明不降低分辨率。
- `test/compression_advisor_test.dart`
  - 更新极限压缩策略测试。
- `test/ffmpeg_command_builder_test.dart`
  - 更新极限压缩命令参数测试。
- `test/ffprobe_media_analyzer_test.dart`
  - 增加音频码率解析断言。

## Added Files

- `docs/archive/logs/2026-04-29-target-bitrate-extreme-compression.md`

## Purpose Of Each Added File

- `docs/archive/logs/2026-04-29-target-bitrate-extreme-compression.md`
  - 记录本次极限压缩策略从 CRF 调整为目标码率控制的原因、实现范围和验证结果。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 当前目标总码率使用第一版经验比例：原始有效码率的 75%，并设置最低值 180k。
- 当前目标视频码率最低值为 120k。
- 当前极限压缩默认音频码率为 64k；如果原音频码率低于 64k，则保留原音频码率。
- 尚未再次使用真实视频验证输出体积是否低于原文件。
- 如果后续仍然变大，需要进一步引入“输出后体积校验 / 自动二次策略”。

## Validation Method Or Test Result

已运行：

```text
dart run build_runner build --delete-conflicting-outputs
dart format ...
flutter analyze
flutter test
```

结果：

```text
No issues found!
All tests passed!
```

当前 `flutter test` 通过 28 个测试。
