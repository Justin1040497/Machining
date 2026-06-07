# 媒体处理扩展

## 所属版本

`v1.1.5`

## 当前事实

FrameLean 从视频专用压缩扩展为视频、图片、音频三类媒体的本地处理工作台。视频仍是最完整链路；图片和音频已支持导入、分析、分类型配置、基础 FFmpeg 输出和完成结果展示。

## 设计方式

- 保留统一任务实体 `MediaTask`。
- 单任务配置从旧视频配置泛化为 `MediaTaskConfig`。
- 视频、图片、音频分别使用 `VideoProcessingConfig`、`ImageProcessingConfig`、`AudioProcessingConfig`。
- Drift `tasks.media_config_json` 保存通用配置；旧视频列继续保留和写入，用于兼容历史任务和降低回滚风险。
- FFprobe 分析结果扩展图片字段和音频字段。
- FFmpeg 命令规划按 `MediaKind` 分派：视频走完整视频规划，图片走步骤型单步计划，音频禁用视频流并按音频配置推导编码参数。
- 应用设置支持默认视频、图片和音频处理配置，设置表使用 `default_media_config_json`。

## 为什么这样设计

如果为视频、图片、音频拆三套任务实体和仓储，队列、状态恢复、输出路径、完成弹窗和工作台操作都会重复。统一 `MediaTask` 能复用已有主流程，同时用分类型配置保持媒体差异清晰。

## 设计收益

- 旧视频任务可兼容读取。
- 任务队列、排序、暂停、取消、重试、完成弹窗和打开输出位置可复用。
- 新增媒体格式时优先扩展配置和命令规划，不必重写工作台。
- 图片和音频缺少视频时长也能用合适进度模式执行。

## 当前边界

- 图片不做高级编辑、水印、批量元数据处理或 GIF 专门优化。
- 音频不做波形、试听、多轨、裁剪、淡入淡出或音量标准化。
- 不引入云端处理、账户体系或 API 链路。
- 旧 `video_*` 数据库列暂不删除。

## 关联

- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/test-plan.md`
- `docs/lessons.md#FFmpeg 编码器能力要在命令构造前校验`
