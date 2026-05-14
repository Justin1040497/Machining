# 2026-04-30 App Default Codec And CLI Preview

## Behavior Summary

- Updated Feishu whiteboards for FFmpeg command building and simple CLI testing.
- Added an app-level compression settings value object.
- Added default output codec to `AppSettings`, with initial value `H.264`.
- Persisted the app default output codec in the settings table.
- Changed CLI codec behavior:
  - no `--codec` argument uses the app default codec, currently `H.264`
  - `--codec source` follows the source video codec
  - `--codec h265` and `--codec hevc` both map to internal HEVC
- Changed user-facing HEVC label to `H.265 / HEVC`.
- Changed CLI preview so normal CRF compression no longer prints misleading target bitrate or estimated output size.
- Target bitrate and estimated output size are only shown for target-bitrate compression.

## Followed Plan / Flowchart

Followed the updated Feishu flowcharts:

- FFmpeg command building now starts from task codec configuration, where task configuration can come from app default settings.
- CLI parsing now treats `--codec` as optional. Missing `--codec` uses app default codec.
- CLI preview separates normal CRF mode from target-bitrate mode.

## Modified Files

- `lib/domain/value_objects/app_compression_settings.dart`
- `lib/domain/entities/app_settings.dart`
- `lib/domain/enums/video_codec.dart`
- `lib/domain/value_objects/video_task_config.dart`
- `lib/infrastructure/database/settings.dart`
- `lib/infrastructure/database/app_database.dart`
- `lib/infrastructure/database/app_database.g.dart`
- `lib/infrastructure/repositories/drift_app_settings_repository.dart`
- `tool/machining_cli.dart`

## Added Files

- `docs/archive/logs/2026-04-30-app-default-codec-and-cli-preview.md`
- `lib/domain/value_objects/app_compression_settings.dart`

## Purpose Of Each Added File

- `docs/archive/logs/2026-04-30-app-default-codec-and-cli-preview.md`: records the completed behavior, changed files, validation, and remaining confirmation points.
- `lib/domain/value_objects/app_compression_settings.dart`: stores app-level compression defaults, starting with the default output video codec.

## Deleted Files

- Temporary Mermaid source files for Feishu updates were removed after the whiteboards were written:
  - `tmp_ffmpeg_command_app_default_codec_flow.mmd`
  - `tmp_cli_app_default_codec_flow.mmd`

## Unfinished Items Or Points Needing Confirmation

- The UI has not yet exposed the app default codec setting.
- CLI currently uses `AppSettings.initial()` for the default codec because the CLI does not load persisted app settings yet.
- HEVC still uses `libx265`; future work should add FFmpeg encoder capability detection.

## Validation

- `dart run build_runner build --delete-conflicting-outputs`: passed.
- `flutter analyze`: passed.
- `flutter test`: passed, 30 tests.
- `dart run tool/machining_cli.dart compress --help`: passed and shows `source|h264|h265|hevc`.
- Feishu whiteboard update commands completed successfully.
