# 极限压缩目标码率比例调优日志

## Behavior Summary

根据真实视频测试反馈，极限压缩在保持原始分辨率的前提下仍然有明显糊感。

本次调整：

- 极限压缩目标总码率比例从 `0.75` 调整为 `0.85`。
- 普通默认压缩保持不变：`CRF 28 + 音频 128k`。
- 极限压缩仍保持不自动降低分辨率。
- 极限压缩仍使用目标码率策略和更低音频码率。

示例：

```text
原始有效码率：0.65 Mbps
旧目标总码率：0.65 * 0.75 = 0.49 Mbps
新目标总码率：0.65 * 0.85 = 0.55 Mbps
```

该调整的目标是在继续压缩体积的同时，减少 1080p 低码率视频的明显糊感。

## Followed Plan Or Flowchart

已更新并遵循飞书白板：

- `FFmpeg 命令构造器`
  - 目标总码率计算从“低于原视频码率”明确为“原视频码率 * 0.85”。

## Modified Files

- `lib/infrastructure/services/default_compression_advisor.dart`
  - `calculateTargetTotalBitrate` 从 `sourceBitrate * 0.75` 改为 `sourceBitrate * 0.85`。
- `test/compression_advisor_test.dart`
  - 更新目标总码率和目标视频码率预期。
- `test/ffmpeg_command_builder_test.dart`
  - 更新极限压缩下 `-b:v`、`-maxrate`、`-bufsize` 参数预期。
- `docs/archive/README.md`
  - 追加本次调优记录。

## Added Files

- `docs/archive/logs/2026-04-30-extreme-compression-ratio-085.md`

## Purpose Of Each Added File

- `docs/archive/logs/2026-04-30-extreme-compression-ratio-085.md`
  - 记录极限压缩目标码率比例从 0.75 调整到 0.85 的原因、修改范围和验证结果。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 还需要用刚才出现明显糊感的真实视频重新验证画质和输出体积。
- 如果仍然糊，可以继续把比例调到 `0.90`；如果体积不够小，可以评估 `0.80`。

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
