# Task Responsibility

Protocol v1 当前区分以下身份：

- `request_id`：Client 生成的会话内幂等键。
- `work_id`：FEngine 为一次外部排队工作生成的身份。
- `client_task_id` / `client_file_id`：Client 持有的关联身份，不作为 FLL Task ID。
- `analysis_id`：FLL AnalysisSnapshot 身份。
- `execution_id`：FLL 成功创建真实 execution 后返回的 Task 身份。

FEngine 外部 Work 的 queued/running/completed/failed 与 FLL `ExecutionTaskState` 是不同层的状态。前者表示一个协议命令的排队与终态，后者表示真实媒体 execution。Client 不能从本地列表位置推断实际队列，必须投影 FEngine 返回的 `queue_position`、queue revision 和 sequence。
