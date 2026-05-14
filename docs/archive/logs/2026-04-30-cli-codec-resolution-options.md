# 2026-04-30 CLI Codec And Resolution Options

## Behavior Summary

- Updated Feishu whiteboards for FFprobe media analysis, FFmpeg command building, and simple CLI testing.
- Changed the default target codec from forced H.264 to source codec preservation.
- Added standard CLI options:
  - `--codec` / `-c`: `source`, `h264`, `hevc`
  - `--resolution` / `-r`: `original`, `2160p`, `1080p`, `720p`, `480p`
- Added compression preview output with source codec, target codec, source size, estimated output size, source bitrate, target bitrate, source resolution, and target resolution.
- Added HEVC command generation through `libx265`, including `hvc1` tagging for MP4/MOV compatibility.

## Followed Plan / Flowchart

Followed the updated Feishu flowcharts:

- FFprobe media analysis: extract source codec, source size, bitrate, and original resolution.
- FFmpeg command building: resolve `source` to the analyzed source codec, support explicit H.264 or HEVC, compute bitrate preview, and generate `FfmpegCommandPlan`.
- Simple CLI: parse standard options with `args`, print compression preview, require user confirmation for low-bitrate videos, then execute FFmpeg.

## Modified Files

- `pubspec.yaml`
- `pubspec.lock`
- `lib/domain/enums/video_codec.dart`
- `lib/domain/enums/encoder_backend.dart`
- `lib/domain/enums/resolution_preset.dart`
- `lib/domain/value_objects/video_task_config.dart`
- `lib/application/services/compression_advisor.dart`
- `lib/infrastructure/services/default_compression_advisor.dart`
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
- `tool/machining_cli.dart`
- `test/ffmpeg_command_builder_test.dart`

## Added Files

- `docs/archive/logs/2026-04-30-cli-codec-resolution-options.md`

## Purpose Of Each Added File

- `docs/archive/logs/2026-04-30-cli-codec-resolution-options.md`: records the completed behavior, changed files, validation, and remaining confirmation points for this implementation step.

## Deleted Files

- Temporary Mermaid source files for Feishu updates were removed after the whiteboards were successfully written:
  - `tmp_ffprobe_bitrate_codec_flow.mmd`
  - `tmp_ffmpeg_command_encoding_flow.mmd`
  - `tmp_cli_standard_options_flow.mmd`

## Unfinished Items Or Points Needing Confirmation

- The HEVC path currently generates `libx265` commands. If app distribution later bundles a specific FFmpeg build, encoder availability should be checked through an FFmpeg capability detector.
- The estimated output size is a preview based on target bitrate and duration, not a guaranteed final file size.
- UI has not been updated yet; future UI should map its codec and resolution controls to the same `VideoTaskConfig` fields.

## Validation

- `flutter analyze`: passed.
- `flutter test`: passed, 30 tests.
- `dart run tool/machining_cli.dart compress --help`: passed after running outside the sandbox because the Flutter toolchain needed to write to its cache.
- Feishu whiteboards were queried after update and returned the expected new text content.
