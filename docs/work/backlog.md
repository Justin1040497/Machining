# 候选任务池

## 维护规则

- 这里记录候选任务，不记录每日进度。
- 状态使用：`候选`、`待确认`、`已排期`、`暂缓`。
- 进入执行时，移动到 `docs/work/active.md`。

| ID | 模块 | 优先级 | 状态 | 候选事项 | 下一步 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| B-001 | 媒体处理 | P1 | 待确认 | 图片和音频端到端手动验收，覆盖 macOS / Windows 发布包中的关键输出格式 | 准备小型样本和验收清单 | `docs/releases/v1.1.5/media-processing.md` |
| B-003 | 执行恢复 | P2 | 候选 | 应用重启后处理数据库残留 `running` 状态的恢复或重置策略 | 先写决策，明确恢复、重试和用户提示边界 | `docs/develop/architecture.md` |
| B-004 | FFmpeg 法律材料 | P1 | 待确认 | 发布前再次校验 FFmpeg / x264 / LAME / libwebp / Opus 许可证材料和源码可得性 | 对照 release 包实际内容更新 `legal/` 和 `docs/reference/` | `docs/reference/ffmpeg-license-distribution.md` |
| B-005 | 专有音频 | P2 | 候选 | QMC 外部适配器发布包级验证和错误提示边界 | 确认是否随包分发适配器，以及许可证和版本探测规则 | `docs/releases/v1.1.5/proprietary-audio-import.md` |
| B-006 | 桌面集成 | P2 | 候选 | 支持在 macOS / Windows 文件右键菜单中将媒体文件添加到 FrameLean 任务列表 | 进入功能分析，确认平台范围、单实例唤起、批量文件导入和右键后只添加不自动开始的边界 | 2026-06-08 用户需求池讨论 |
| B-007 | 桌面集成 | P2 | 候选 | 支持 Windows 托盘图标展示待机和运行中状态，运行中用低频动态圆形进度环显示当前最快完成任务进度 | 进入功能分析，确认 Windows 优先级、后台窗口关闭策略、进度来源、刷新频率和资源占用验收指标 | 2026-06-08 用户需求池讨论 |
