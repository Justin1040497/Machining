# FFmpeg 收尾返回结果阶段完成日志

## Behavior Summary

实现 FFmpeg 收尾返回结果阶段。当前任务经过观测阶段得到 completed / failed / 其他终态后，队列执行器会重新读取 `tasks` 表，重新计算队列状态，并根据连续执行开关决定是否继续执行下一个 pending 任务。

当前默认开启连续执行：

- 如果还有 running 任务，队列保持 `running`。
- 如果没有 running 但还有 pending，且连续执行开启，则继续取下一个 pending 任务。
- 如果没有 running 但还有 pending，且连续执行关闭，则队列停在 `ready`，等待用户再次点击开始。
- 如果没有 running 和 pending，则队列回到 `idle`。

## Followed Plan Or Flowchart

遵循飞书最后一个白板中的 `FFmpeg 收尾返回结果阶段` 流程图：

- 观测阶段返回当前任务结果
- 保存当前任务最终状态
- 重新读取 tasks 表
- 判断 running 任务
- 判断 pending 任务
- 判断是否开启连续执行
- 回到取任务阶段或结束

## Modified Files

- `lib/application/services/ffmpeg_task_queue_runner.dart`
  - 新增 `continuousExecutionEnabled` 构造参数，默认开启连续执行。
  - 将单任务执行逻辑拆到 `_runNextPendingTask`。
  - 新增 `finishAfterTask`，在每个任务终态后重新读取任务表并计算队列状态。
  - 当连续执行开启且仍有 pending 任务时，自动回到取任务阶段继续执行。
- `test/ffmpeg_task_queue_runner_test.dart`
  - 更新默认执行测试，覆盖连续处理多个 pending 任务。
  - 新增关闭连续执行时停在 `ready` 的测试。

## Added Files

No added files.

## Purpose Of Each Added File

No added files.

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 目前连续执行默认开启，但 UI 还没有暴露“连续执行”开关。
- 暂停、取消、并发限制、失败后是否继续等策略还没有做成用户可配置项。
- 现在 `start()` 返回的是本轮连续执行中的最后一个任务结果；任务列表本身仍会保存每个任务的真实状态。

## Validation Method Or Test Result

已运行：

```text
dart analyze lib/application/services/ffmpeg_task_queue_runner.dart test/ffmpeg_task_queue_runner_test.dart
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
