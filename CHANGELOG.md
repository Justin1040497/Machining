# 更新日志

本文件只保留 FrameLean 正式版本的用户可感知变化摘要。详细设计、兼容性和迁移事实见 `docs/releases/`；重要决策见 `docs/decisions/`。

## 2026-07-15｜v1.2.1｜Release

### Added

- 新增任务夹批量工作流、夹级配置、拖入 / 移出、排序、聚合日志和作用域执行。
- 新增受控并行、手动任务抢占与 FIFO 恢复，以及隐藏 partial 输出和原子发布链。
- 新增工作台更新状态、轻量通知、完整版本日志和 GitHub / Gitee / 备用下载入口。
- 新增通知策略、快捷键、关闭到后台、并行上限和文件夹扫描深度设置。
- 新增不拦截前景交互的低透明度工作台背景引导和空白背景双击导入。

### Changed

- 视频输出扩展到受约束的 MP4、MOV、MKV、WebM、AVI 容器 / 编码组合；透明视频固定使用 MOV + ProRes 4444 保留 alpha。
- 导入、分析、执行和恢复使用统一状态与结构化失败模型；图片和音频压缩增加输出有效性验收。
- 公开更新默认跳转外部下载页，package 自更新链继续保留但不再作为默认发布路径。
- README 更新产品截图、macOS 安装步骤和精简结构；仓库移除旧设计截图、机器相关 Claude Alias 与可由 CI 重建的二进制。
- 项目 Skills、文档入口、PR 与 Release 文案完成瘦身，移除空需求池、过时执行计划和逐日变更流水。

### Fixed

- 修复分析调度死锁、资源租约补位、暂停不释放执行位和快速分析后界面状态滞后问题。
- 修复输出权限误判、目标或 partial 被删除、最终文件不可读和发布失败仍可能标记完成的问题。
- 修复无效图片 / 音频压缩、透明视频 alpha 丢失、FFprobe / FFmpeg 超时残留和硬件编码会话失效问题。
- 修复任务夹共同设置、排序、跨夹拖拽、快捷键录入、设置回滚和通知语义问题。
- 修复多组背景引导交叉、文字压线、箭头连接不自然及空间不足时错误显示的问题。

完整说明见 [`docs/releases/v1.2.1/release.md`](docs/releases/v1.2.1/release.md)。

## 2026-06-14｜v1.2.0｜Release

### Added

- 新增图片 / 音频统一任务模型、分类型配置、FFprobe 分析和基础 FFmpeg 处理。
- 新增 NCM 本地还原、QMC 外部适配输入、持久化通知中心、完成提示音和输出文件名模板。
- 新增 HDR10 / HLG 转 SDR、受限保持 HDR、macOS Universal 2 与 Windows 安装器发布链。

### Changed

- 完成 Clean Architecture composition root、平台服务抽象和共享展示组件治理。
- 媒体默认值、保持原始格式、元数据保留和输出位置语义统一。

### Fixed

- 修复 Drift 迁移、任务排序、主题缓存、非视频详情、输出命名、HDR 参数和跨平台打包问题。

详细事实见 [`docs/releases/v1.2.0/`](docs/releases/v1.2.0/)。

## 2026-05-29｜v1.1.5｜Release

- 扩展图片 / 音频处理和专有音频输入适配。
- 加入深浅主题、任务拖拽排序，并统一 macOS / Windows 发布产物命名与仓库结构。

详细事实见 [`docs/releases/v1.1.5/`](docs/releases/v1.1.5/)。

## 2026-05-27｜v1.1.0｜Release

- 完善 Windows 进程暂停 / 恢复、Explorer 定位、FFmpeg 输出参数与 Windows 打包布局。
- 增加更完整的 FFprobe 分析字段和已完成任务“重来”入口。

详细事实见 [`docs/releases/v1.1.0/`](docs/releases/v1.1.0/)。

## 2026-05-26｜v1.0.0｜Release

- 发布 FrameLean 更名后的首个桌面版本，提供视频导入、分析、压缩配置、任务队列、预览、设置和结果定位。
- 支持 macOS Apple Silicon 与 Windows x64 发布包。

详细事实见 [`docs/releases/v1.0.0/`](docs/releases/v1.0.0/)。
