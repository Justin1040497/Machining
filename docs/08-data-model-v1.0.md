# 数据模型 v1.0

## 数据库

Machining 使用 Drift + SQLite。当前 schema 版本为 7。

数据库由 `AppDatabase` 管理，主要表：

- `tasks`
- `settings`

## tasks

任务表保存导入文件、处理配置、分析结果和执行状态。

核心字段：

- `id`：任务 ID
- `input_path`：源文件路径
- `file_name`：显示文件名
- `media_kind`：媒体类型
- `purpose`：任务用途
- `status`：任务状态
- `progress`：执行进度
- `sort_order`：列表排序
- `output_path`：输出文件路径
- `error_message`：失败原因
- `created_at`
- `started_at`
- `completed_at`
- `failed_at`

视频配置字段：

- `output_format`
- `video_codec`
- `encoder_backend`
- `resolution_preset`
- `output_directory`
- `compression_crf`
- `output_file_name`

分析与源文件字段：

- `analysis_json`
- `analysis_updated_at`
- `analysis_error_message`
- `source_file_fingerprint_json`

## settings

设置表保存应用级偏好。

核心字段：

- `id`
- `default_output_directory`
- `last_selected_output_directory`
- `custom_ffmpeg_path`
- `custom_ffprobe_path`
- `show_raw_log`
- `show_advanced_options`
- `default_output_video_codec`

## 任务状态

- `pending`：待处理
- `running`：处理中
- `paused`：已暂停
- `completed`：完成
- `failed`：失败
- `missingSource`：源文件缺失

## 迁移原则

- 新字段优先提供默认值，避免破坏已有任务
- 枚举值存储必须保持向后兼容
- JSON 字段用于分析结果和指纹等结构化但变化较快的数据
- 任务执行状态必须能从数据库恢复到安全状态

## 1.1 数据模型候选

- `task_logs`：如果日志索引需要从临时文件目录升级为数据库管理
- `history` 或扩展 `tasks`：支持历史视图和归档
- `presets`：压缩参数模板
- `benchmark_results`：真实素材压缩基准记录
