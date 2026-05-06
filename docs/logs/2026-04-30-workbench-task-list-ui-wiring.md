# 2026-04-30 Workbench Task List UI Wiring

## Behavior Summary

Connected the left task list UI to real task data and task-list operations.
The list now reads `mediaTaskListProvider` instead of demo tasks, supports adding local video files through the desktop file selector, supports clearing the full task list after confirmation, and supports drag sorting with persisted `sortOrder`.

## Followed Plan Or Flowchart

Followed the confirmed task-list plan:

1. Replace demo task list with real task data.
2. Add local video file selection from the add button.
3. Create real `MediaTask.draft` records and trigger background FFprobe analysis.
4. Rename the delete action to clear list and require confirmation before clearing.
5. Persist drag sorting by rewriting `sortOrder`.
6. Keep task-list logic in the notifier and keep the page as a UI caller.

## Modified Files

- `pubspec.yaml`
- `pubspec.lock`
- `lib/application/services/ffmpeg_task_queue_runner.dart`
- `lib/features/workbench/providers/media_task_notifier.dart`
- `lib/features/workbench/pages/workbench_page.dart`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`
- `test/ffmpeg_task_queue_runner_test.dart`

## Added Files

No added source files.

## Purpose Of Each Added File

No added source files.

## Deleted Files

No deleted files.

## Unfinished Items Or Points Needing User Confirmation

- The right-side preview, compression parameter persistence, and queue control bar are still not connected in this step.
- The file selector is a native desktop plugin. After adding `file_selector` and macOS entitlements, the app needs a full stop and restart/rebuild; hot reload is not enough for native plugin registration or entitlement changes.
- Drag-and-drop file import is intentionally out of scope for this step.

## Validation Method Or Test Result

- `flutter pub add file_selector` succeeded.
- `dart format` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed: 37 tests passed.
