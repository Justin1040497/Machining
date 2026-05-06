# FFmpeg 任务切换 / 挂起恢复阶段完成日志

## Behavior Summary

实现 FFmpeg 任务切换 / 挂起恢复阶段。执行器从“等待单个任务完成”的串行结构，调整为“执行上下文表 + 后台观测”的结构。

当前行为：

- 同一时间只有一个前台任务真正编码。
- 前台任务可以通过 `SIGSTOP` 挂起，任务状态变为 `paused`。
- 已挂起任务可以通过 `SIGCONT` 恢复，任务状态变回 `running`。
- 执行器用 `_executions[taskId]` 保存仍然存活的 FFmpeg 进程上下文。
- 执行器用 `_foregroundTaskId` 表示当前前台运行任务。
- 观测器改为后台等待任务结束，不再阻塞任务切换。
- 取消任务会 kill 对应 FFmpeg 进程，并将任务状态改为 `cancelled`。

## Followed Plan Or Flowchart

遵循飞书最后一个白板中的 `FFmpeg任务切换/挂起恢复阶段` 流程图：

- 设计约束 / 执行模型
- 用户点击某个任务：开始 / 继续
- 用户点击当前任务：暂停
- 用户点击任务：取消
- 后台观测与收尾

## Modified Files

- `lib/domain/enums/task_status.dart`
  - 新增 `paused` 状态，中文标签为 `已暂停`。
- `lib/domain/entities/media_task.dart`
  - 新增 `markPaused`，用于把 running 任务标记为挂起。
  - 新增 `markResumed`，用于把 paused 任务恢复为 running。
  - 新增 `markCancelled`，用于把任务标记为取消。
- `lib/application/services/ffmpeg_task_queue_runner.dart`
  - 新增 `TaskExecution` 和 `TaskExecutionState`。
  - 新增 `_executions` 执行上下文表。
  - 新增 `_foregroundTaskId` 前台任务标记。
  - 新增 `startOrResumeTask`、`pauseTask`、`cancelTask`。
  - 将 FFmpeg 观测改为后台 `unawaited` 处理。
  - 通过 `SIGSTOP` 挂起当前前台任务，通过 `SIGCONT` 恢复已挂起任务。
- `test/ffmpeg_task_queue_runner_test.dart`
  - 重写队列执行器测试，使其适配后台观测和任务切换模型。
  - 覆盖启动前台任务、切换任务、恢复任务、暂停任务、取消挂起任务、后台观测完成等行为。

## Added Files

No added files.

## Purpose Of Each Added File

No added files.

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 该方案依赖 `SIGSTOP` / `SIGCONT`，主要适合 macOS / Linux。
- App 退出后无法恢复仍处于 `paused` 的活进程。
- `paused` 任务仍占用 FFmpeg 进程、文件句柄和半成品输出文件。
- 当前还没有 UI 接入这些任务级按钮。
- Windows 如需支持类似能力，需要单独实现平台相关进程暂停 / 恢复逻辑，或改用“停止后重跑”策略。

## Validation Method Or Test Result

已运行：

```text
dart analyze lib/domain/enums/task_status.dart lib/domain/entities/media_task.dart lib/application/services/ffmpeg_task_queue_runner.dart lib/infrastructure/providers/ffmpeg_provider.dart test/ffmpeg_task_queue_runner_test.dart
```

结果：

```text
No issues found!
```

已尝试运行：

```text
flutter test test/ffmpeg_task_queue_runner_test.dart
```

结果：未能进入测试用例执行。`sqlite3` 依赖需要从 GitHub 下载 `libsqlite3.arm64.macos.dylib`，网络连接超时，测试流程在依赖下载阶段失败。
