# 候选任务池

## 维护规则

- 这里记录候选任务，不记录每日进度。
- 状态使用：`候选`、`待确认`、`已排期`、`暂缓`。
- 进入执行时，移动到 `docs/work/active.md`。

| ID | 模块 | 优先级 | 状态 | 候选事项 | 下一步 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| B-004 | FFmpeg 法律材料 | P1 | 候选 | 发布前再次校验 FFmpeg / x264 / LAME / libwebp / Opus / zimg 许可证材料和源码可得性 | v1.2.0 法律材料目录已完成治理；发布前对照 DMG 实际内容复核 `legal/` 和 `docs/reference/` | `docs/reference/ffmpeg-license-distribution.md` |
| B-005 | 专有音频 | P2 | 候选 | QMC 外部适配器发布包级验证和错误提示边界 | 确认是否随包分发适配器，以及许可证和版本探测规则 | `docs/releases/v1.1.5/proprietary-audio-import.md` |
| B-006 | 桌面集成 | P2 | 候选 | 支持在 macOS / Windows 文件右键菜单中将媒体文件添加到 FrameLean 任务列表 | 进入功能分析，确认平台范围、单实例唤起、批量文件导入和右键后只添加不自动开始的边界 | 2026-06-08 用户需求池讨论 |
| B-007 | 桌面集成 | P2 | 候选 | 支持 Windows 托盘图标展示待机和运行中状态，运行中用低频动态圆形进度环显示当前最快完成任务进度 | 进入功能分析，确认 Windows 优先级、后台窗口关闭策略、进度来源、刷新频率和资源占用验收指标 | 2026-06-08 用户需求池讨论 |
| B-008 | 视频压缩 | P1 | 待确认 | 单独校准压缩质量预设，重点评估当前“均衡”CRF 28 相比 HandBrake RF22、小丸 23.5 / 24 对暗部渐变、色带和体积的影响 | 准备样片矩阵，分别为软件 CRF、NVENC CQ、QSV global quality、AMF QP 和 VideoToolbox `q:v` 设计预设映射 | `docs/decisions/260613-video-color-hdr-sdr-boundary.md` |
| B-009 | 视频色彩 | P2 | 候选 | 评估 Dolby Vision 高级处理路线，包括 `libplacebo` tone mapping 或独立 `libdovi` RPU 处理 | 先收集 Profile 5 / Profile 8 样片和 FFmpeg 构建影响，再决定是否进入实现 | `docs/decisions/260613-video-color-hdr-sdr-boundary.md` |
