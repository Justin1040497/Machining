# v1.1.5 版本概览

## 当前事实

`v1.1.5` 是当前主要开发版本。它在 `v1.1.0` 的视频压缩工作台基础上，扩展了图片 / 音频处理、部分专有音频输入适配、工作台主题和拖拽排序，并整理了仓库结构和项目级 skills。

## 重要事实设计

| 文档 | 说明 |
| --- | --- |
| `media-processing.md` | 视频 / 图片 / 音频统一任务模型和处理边界 |
| `proprietary-audio-import.md` | NCM 和 QMC 输入适配边界 |
| `workbench-theme-and-reorder.md` | 深浅主题、启动缓存、任务拖拽排序和 UI 体验 |
| `repository-structure.md` | 仓库根目录和文档信息架构治理 |
| `project-skills-workflow.md` | 项目级 skills 职责收敛、共享预读协议和 release / delivery 分工 |

## 当前仍需验证

- 图片和音频发布包级端到端手动验收。
- macOS / Windows 发布包中的关键图片、音频、专有音频输入和编码器链路。
- FFmpeg 法律材料与当前构建参数、内置编码器保持一致。

候选任务见 `docs/work/backlog.md`。
