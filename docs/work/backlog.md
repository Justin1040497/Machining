# 候选任务池

## 维护规则

- 这里记录候选任务，不记录每日进度。
- 状态使用：`候选`、`待确认`、`已排期`、`暂缓`。
- 进入执行时，移动到 `docs/work/active.md`。

| ID | 模块 | 优先级 | 状态 | 候选事项 | 下一步 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| B-001 | 媒体处理 | P1 | 待确认 | 图片和音频端到端手动验收，覆盖 macOS / Windows 发布包中的关键输出格式 | 准备小型样本和验收清单 | `docs/releases/v1.1.5/media-processing.md` |
| B-002 | 主题 | P2 | 候选 | 支持跟随系统外观 `AppThemeMode.system` | 先确认是否需要设置页入口和启动行为 | `docs/releases/v1.1.5/workbench-theme-and-reorder.md` |
| B-003 | 执行恢复 | P2 | 候选 | 应用重启后处理数据库残留 `running` 状态的恢复或重置策略 | 先写决策，明确恢复、重试和用户提示边界 | `docs/develop/architecture.md` |
| B-004 | FFmpeg 法律材料 | P1 | 待确认 | 发布前再次校验 FFmpeg / x264 / LAME / libwebp / Opus 许可证材料和源码可得性 | 对照 release 包实际内容更新 `legal/` 和 `docs/reference/` | `docs/reference/ffmpeg-license-distribution.md` |
| B-005 | 专有音频 | P2 | 候选 | QMC 外部适配器发布包级验证和错误提示边界 | 确认是否随包分发适配器，以及许可证和版本探测规则 | `docs/releases/v1.1.5/proprietary-audio-import.md` |
