# 当前任务

## 维护规则

- 只记录当前正在推进的事项，保持 1 页以内。
- 每个事项必须有下一步，不记录模糊愿望。
- 完成后将结果写入 `CHANGELOG.md`、`docs/releases/`、`docs/lessons.md` 或 `docs/decisions/` 中合适的位置，然后从这里移除。

## 进行中

### 导入到视频导出稳定化

- 当前：B-010～B-012 已完成。任务链统一为 `awaitingAnalysis → analyzing → pending → running → completed`；首次执行受 `canStartExecution` 硬准入保护；失败统一由 schema 30 的 `TaskFailure` 持久化。队列补位、并发分析、最终发布和内核拆分均已有自动化回归。
- 下一步：只剩正式安装包发布验收——使用包内 FFmpeg / FFprobe 在 Apple Silicon、Intel Mac 和 Windows x64 连续三轮执行真实视频矩阵。
- 发布边界：任一平台未完成真实视频三轮稳定性闭环前，不视为达到 v1.2.1 发布标准。
