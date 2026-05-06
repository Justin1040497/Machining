# FFmpeg 观测阶段完成日志

## Behavior Summary

实现 FFmpeg 进程观测阶段。队列执行器在启动 FFmpeg 进程后，会把已启动进程交给观测器处理。

观测器负责：

- 读取 `stdout` 中来自 `-progress pipe:1` 的结构化进度信息。
- 解析 `out_time_ms`，在任务已有媒体总时长时计算并保存 `progress`。
- 读取 `stderr` 并追加写入原始日志文件。
- 等待 FFmpeg `exitCode`。
- 根据 `exitCode` 和输出文件是否存在，返回 completed 或 failed。

`stderr` 只作为日志线索保存，不直接等于任务失败。

## Followed Plan Or Flowchart

遵循飞书最后一个白板中的 `FFmpeg 观测阶段` 流程图：

- 进度观测：stdout
- 日志观测：stderr
- 结束判断：exitCode + 输出文件

## Modified Files

- `lib/domain/entities/media_task.dart`
  - 新增 `withProgress`，用于更新运行中任务进度。
  - 新增 `markCompleted`，用于任务成功完成时写入完成状态和完成时间。
- `lib/application/services/ffmpeg_task_queue_runner.dart`
  - 在 FFmpeg 进程启动成功后调用 `FfmpegProcessObserver`。
  - 根据观测结果将任务更新为 completed 或 failed。
  - 进度回调中保存当前任务的 `progress`。
- `lib/infrastructure/services/local_ffmpeg_process_starter.dart`
  - 移除对 stdout / stderr 的提前监听，避免抢占观测器需要读取的输出流。
  - 保留启动命令和参数写入日志文件。
- `lib/infrastructure/providers/ffmpeg_provider.dart`
  - 新增 `ffmpegProcessObserverProvider`。
  - 将观测器注入队列执行器。
- `test/ffmpeg_task_queue_runner_test.dart`
  - 更新队列执行器测试，让启动后进入观测并完成当前任务。
  - 新增观测失败时任务变为 failed 的测试。

## Added Files

- `lib/application/services/ffmpeg_process_observer.dart`
  - 定义 FFmpeg 进程观测抽象和观测结果。
- `lib/infrastructure/services/local_ffmpeg_process_observer.dart`
  - 实现本机 FFmpeg stdout 进度解析、stderr 日志保存、退出码判断和输出文件检查。
- `test/ffmpeg_process_observer_test.dart`
  - 覆盖进度解析、无媒体总时长、非零退出码和输出文件缺失。

## Purpose Of Each Added File

- `ffmpeg_process_observer.dart`
  - 让队列执行器依赖抽象，保持队列推进和进程观测职责分离。
- `local_ffmpeg_process_observer.dart`
  - 承担真实本机进程的 stdout / stderr / exitCode 观测逻辑。
- `ffmpeg_process_observer_test.dart`
  - 固定观测阶段的关键规则，特别是 `stderr` 不直接等于失败、`out_time_ms` 需要总时长才能换算百分比。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 当前完成的是单个任务从 running 到 completed / failed 的观测闭环。
- 尚未实现收尾阶段的连续执行下一条 pending 任务。
- 尚未实现暂停、取消、剩余时间、速度显示等扩展行为。
- `out_time_ms` 按 FFmpeg progress 的微秒值处理，计算时使用 `durationMs * 1000`。

## Validation Method Or Test Result

已运行：

```text
dart analyze lib/domain/entities/media_task.dart lib/application/services/ffmpeg_process_observer.dart lib/application/services/ffmpeg_process_starter.dart lib/application/services/ffmpeg_task_queue_runner.dart lib/infrastructure/services/local_ffmpeg_process_observer.dart lib/infrastructure/services/local_ffmpeg_process_starter.dart lib/infrastructure/providers/ffmpeg_provider.dart test/ffmpeg_task_queue_runner_test.dart test/ffmpeg_process_observer_test.dart
```

结果：

```text
No issues found!
```

已尝试运行：

```text
flutter test test/ffmpeg_process_observer_test.dart test/ffmpeg_task_queue_runner_test.dart
```

结果：未能进入测试用例执行。`sqlite3` 依赖需要从 GitHub 下载 `libsqlite3.arm64.macos.dylib`，网络连接超时，测试流程在依赖下载阶段失败。
