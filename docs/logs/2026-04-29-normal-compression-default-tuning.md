# 普通默认压缩策略调优日志

## Behavior Summary

根据真实视频测试反馈，普通默认压缩策略过于保守，出现 110MB 视频压缩后仍为 106MB 的情况。

本次调整：

- 普通默认压缩从 `CRF 25` 调整为 `CRF 28`。
- 普通默认音频码率从 `192k` 调整为 `128k`。
- 极限压缩策略保持不变：
  - 低码率视频仍先提醒用户确认。
  - 用户确认后使用目标码率策略。
  - 不自动降低分辨率。

调整后的普通默认策略：

```text
-c:v libx264
-preset slow
-crf 28
-pix_fmt yuv420p
-c:a aac
-b:a 128k
```

## Followed Plan Or Flowchart

已更新并遵循飞书白板：

- `FFmpeg 命令构造器`
  - 普通默认压缩建议改为 `CRF 28 + 音频 128k`。
- `简易CLI - 核心功能测试`
  - 普通默认压缩策略改为 `CRF 28 + 音频 128k`。

## Modified Files

- `lib/infrastructure/services/default_compression_advisor.dart`
  - 普通压缩 `normalCrf` 从 25 改为 28。
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
  - 普通压缩默认音频码率从 192k 改为 128k。
- `test/ffmpeg_command_builder_test.dart`
  - 更新普通压缩命令参数预期。
- `test/compression_advisor_test.dart`
  - 更新普通压缩 CRF 预期。
- `docs/log.md`
  - 追加本次普通默认压缩策略调优记录。

## Added Files

- `docs/logs/2026-04-29-normal-compression-default-tuning.md`

## Purpose Of Each Added File

- `docs/logs/2026-04-29-normal-compression-default-tuning.md`
  - 记录普通默认压缩策略调整原因、修改范围和验证结果。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 还需要用真实 110MB 样片重新验证默认压缩比例。
- 如果默认压缩仍不明显，后续可以继续评估 `CRF 29/30`，或增加用户可选压缩档位。

## Validation Method Or Test Result

已运行：

```text
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
