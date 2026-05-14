# 2026-04-30 Preview Frame Generator

## Behavior Summary

Implemented the preview frame generation service described in the Feishu whiteboard "预览图显示".
The service generates 5 comparison frame pairs for a selected video task.

It samples the source video at 5%, 27.5%, 50%, 72.5%, and 95% of the duration.
For each sample point, it extracts one original frame, creates a 1-second compressed preview segment using the current compression parameters, and extracts one compressed frame from the middle of that segment.

## Followed Plan Or Flowchart

Followed the Feishu whiteboard flow:

1. User selects a task with FFprobe analysis.
2. User changes codec, resolution, quality, or output format.
3. User clicks generate comparison frames.
4. The system validates task analysis and parameters.
5. The system calculates 5 dispersed preview timestamps.
6. The system creates a task preview directory.
7. The system extracts 5 original frames.
8. The system generates compressed preview material with current compression parameters.
9. The system returns preview frame paths and a parameter fingerprint.
10. If compression parameters change later, the previous preview is treated as expired.

## Modified Files

- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
- `lib/infrastructure/providers/ffmpeg_provider.dart`
- `test/ffmpeg_command_builder_test.dart`

## Added Files

- `lib/application/services/preview_frame_generator.dart`
- `lib/infrastructure/services/local_preview_frame_generator.dart`
- `test/preview_frame_generator_test.dart`

## Purpose Of Each Added File

- `preview_frame_generator.dart`: Defines the application-layer preview frame API, request/result models, frame pair model, fingerprint model, and preview generation exception.
- `local_preview_frame_generator.dart`: Implements the local FFmpeg-based preview frame generator.
- `preview_frame_generator_test.dart`: Verifies 5-frame generation, missing-duration handling, parameter fingerprint expiration, and FFmpeg failure handling.

## Deleted Files

No deleted files.

## Unfinished Items Or Points Needing User Confirmation

- UI integration is not implemented yet. The provider is ready for the UI to call.
- The current implementation generates 1-second preview segments before extracting compressed frames, which is more realistic than applying image-only compression to JPEG frames.
- The preview directory is under the system temp directory: `/tmp/machining/previews/<taskId>/`.
- Preview segment files are intermediate files only. Each `preview_segment_*` file is deleted immediately after the compressed preview frame is extracted, and failures also attempt cleanup through `finally`.

## Validation Method Or Test Result

- `dart format` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed: 36 tests passed.
- After user feedback, preview sampling was adjusted from 10% / 30% / 50% / 70% / 90% to 5% / 27.5% / 50% / 72.5% / 95%, while keeping each preview segment at 1 second.
- The Feishu whiteboard "预览图显示" was updated with preview segment cleanup rules.
