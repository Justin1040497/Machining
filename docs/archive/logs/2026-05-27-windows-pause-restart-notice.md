# 2026-05-27 Windows Pause Restart Notice

## Problem Summary

本次修复集中处理三个用户可见问题：

- Windows 上运行中的任务点击“暂停”后再点击“继续”，任务状态会回到运行中，但进度条卡住，后续不再完成。
- 任务压缩完成后缺少明确的“重来”入口，用户不能从分析阶段重新开始同一个任务。
- 当列表里只有一个视频任务时，顶部通知会遮挡任务列表第一项右侧的开始、暂停、继续、重试或删除按钮。

## Root Cause

暂停 / 继续问题的核心原因是队列执行器直接调用 `ProcessSignal.sigstop` 和 `ProcessSignal.sigcont`。这套信号语义适合 macOS / Linux，但不适合作为 Windows 的 FFmpeg 暂停实现。Windows 上 UI 可能已经把任务标记为暂停或恢复，但底层 FFmpeg 进程和后台观测状态并没有可靠同步。

另一个边界问题是后台观测在任务处于 `paused` 状态时收到进程终态会直接返回，导致任务可能卡在暂停或运行状态，无法完成收尾。

“重来”问题来自任务列表动作映射：`completed` 状态没有独立操作，完成弹窗也只提供打开输出位置和关闭。

通知遮挡问题来自 Windows 窗口没有 macOS 自定义顶部栏，但通知仍按顶部浮层显示；任务列表第一项距离窗口顶部太近，单任务场景下右侧按钮会被通知覆盖。

## Fix

新增 `FfmpegProcessController` application 抽象，把暂停、继续和终止从队列执行器中剥离出来：

- macOS / Linux 使用 `SignalFfmpegProcessController`，继续通过 `ProcessSignal.sigstop`、`ProcessSignal.sigcont` 和 `sigterm` 控制 FFmpeg。
- Windows 使用 `WindowsFfmpegProcessController`，通过 `framelean/process_control` method channel 调用 runner 原生实现。
- Windows runner 新增 `process_control_channel.cpp`，按 pid 枚举 FFmpeg 进程线程，并使用 `SuspendThread` / `ResumeThread` 实现暂停和继续，使用 `TerminateProcess` 实现终止。
- 队列执行器改为只调用 `FfmpegProcessController`，并允许暂停状态下的后台观测继续进入收尾流程，避免任务卡住。

任务重来入口改为：

- `TaskStatus.completed` 在任务列表显示“重来”按钮，图标为 replay。
- 完成弹窗新增“重来”按钮，点击后关闭弹窗并调用现有重试流程。
- 重试流程继续使用 `retryTaskById()`，会重新检查源文件、读取指纹、清空旧分析结果并进入 `analyzing`，因此是从分析阶段重新开始。

通知遮挡修复为：

- Windows 工作台顶部新增白色通知安全区。
- Windows 通知定位到该安全区内，任务列表整体下移，避免覆盖第一条任务的右侧操作按钮。

## Modified Files

- `lib/application/services/execution/ffmpeg_process_controller.dart`
- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`
- `lib/infrastructure/providers/execution_provider.dart`
- `lib/infrastructure/services/execution/signal_ffmpeg_process_controller.dart`
- `lib/infrastructure/services/execution/windows_ffmpeg_process_controller.dart`
- `windows/runner/process_control_channel.cpp`
- `windows/runner/process_control_channel.h`
- `windows/runner/flutter_window.cpp`
- `windows/runner/CMakeLists.txt`
- `lib/features/workbench/widgets/media_task_list/media_task_action_button.dart`
- `lib/features/workbench/pages/workbench_page.dart`
- `lib/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart`
- `lib/features/workbench/pages/workbench_page/layout/workbench_shell.dart`
- `lib/features/workbench/pages/workbench_page/overlays/workbench_notice.dart`
- `test/ffmpeg_task_queue_runner_test.dart`
- `test/widget_test.dart`
- `docs/develop/architecture.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
- `docs/archive/changelog.md`

## Validation

- `flutter analyze`
- `flutter test`

## Remaining Confirmation

- 当前环境是 macOS，已完成 Dart 分析和全量 Flutter 测试。
- Windows runner 原生代码已接入 CMake，但仍需要在 Windows 机器上执行 `flutter build windows` 并用真实视频手动验证暂停、继续、完成和重来流程。
