# FFmpeg 执行队列启动阶段完成日志

## Behavior Summary

实现 FFmpeg 执行队列的启动、取任务、命令构建和进程启动阶段。

当前执行器会维护一个队列状态：`idle`、`ready`、`running`。用户点击开始后，执行器会读取任务表，按 `sortOrder` 取第一个 `pending` 任务，检查源文件和 FFmpeg Runtime，调用命令构造器生成 `FfmpegCommandPlan`，创建原始日志文件，然后启动 FFmpeg 进程。

本次没有实现进度解析、完成收尾、暂停、取消和连续执行下一条任务。这些属于后续“观测阶段 / 收尾阶段”。

## Followed Plan Or Flowchart

遵循飞书 `FFmpeg 执行` 白板中的流程图：

- 启动阶段
- 设计约束
- 取任务阶段
- 命令构建阶段
- 运行阶段

## Modified Files

- `lib/domain/entities/media_task.dart`
  - 新增 `markRunning` 和 `markFailed`，集中表达任务进入运行中和失败状态的领域行为。
- `lib/infrastructure/providers/ffmpeg_provider.dart`
  - 新增 FFmpeg 进程启动器 Provider。
  - 新增 FFmpeg 任务队列执行器 Provider。
  - 新增执行日志文件路径生成函数。
- `lib/features/workbench/providers/media_task_notifier.dart`
  - 在任务列表加载、创建、保存、删除、重新指定源文件和分析结果更新后，同步刷新 FFmpeg 队列状态。

## Added Files

- `lib/application/services/ffmpeg_process_starter.dart`
  - 定义 FFmpeg 进程启动抽象和启动结果对象。
- `lib/application/services/ffmpeg_task_queue_runner.dart`
  - 定义队列状态、启动结果和默认队列执行器。
- `lib/infrastructure/services/local_ffmpeg_process_starter.dart`
  - 使用 `Process.start` 启动本机 FFmpeg，并把 stdout / stderr 写入原始日志文件。
- `test/ffmpeg_task_queue_runner_test.dart`
  - 覆盖队列状态、取第一个 pending 任务、源文件丢失、FFmpeg 不可用、命令构建失败、进程启动成功和进程启动失败。

## Purpose Of Each Added File

- `ffmpeg_process_starter.dart`
  - 让队列执行器依赖抽象，便于测试时替换真实进程启动。
- `ffmpeg_task_queue_runner.dart`
  - 把队列状态和执行启动流程集中在 application 层，避免 UI 直接操作任务表和 FFmpeg 进程。
- `local_ffmpeg_process_starter.dart`
  - 承担本机进程启动和原始日志写入。
- `ffmpeg_task_queue_runner_test.dart`
  - 固定流程图中的关键分支，方便后续实现观测阶段时避免破坏启动阶段。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 进度解析还未实现，当前只把 `-progress pipe:1` 输出写入原始日志。
- FFmpeg 退出码、输出文件存在性、任务完成 / 失败收尾还未实现。
- 暂停、取消和继续执行下一条 pending 任务还未实现。
- 当前执行日志放在系统临时目录 `machining/ffmpeg-logs` 下，后续可以确认是否改为应用支持目录。

## Validation Method Or Test Result

已运行：

```text
dart analyze lib/domain/entities/media_task.dart lib/application/services/ffmpeg_process_starter.dart lib/application/services/ffmpeg_task_queue_runner.dart lib/infrastructure/services/local_ffmpeg_process_starter.dart lib/infrastructure/providers/ffmpeg_provider.dart lib/features/workbench/providers/media_task_notifier.dart test/ffmpeg_task_queue_runner_test.dart
```

结果：

```text
No issues found!
```

已尝试运行：

```text
flutter test test/ffmpeg_task_queue_runner_test.dart
```

结果：未能进入测试用例执行。`sqlite3` 依赖需要从 GitHub 下载 `libsqlite3.arm64.macos.dylib`，在普通沙箱和放开权限后都出现网络连接超时。
