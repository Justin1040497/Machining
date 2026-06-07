# FrameLean 项目上下文

## 项目定位

FrameLean（帧轻）是一个本地桌面媒体压缩与格式处理工具。它基于 Flutter Desktop、FFmpeg / FFprobe、Riverpod、Drift 和 SQLite，把常见视频、图片、音频分析、压缩、格式输出配置和任务队列能力封装成图形界面。

项目当前定位是本地桌面应用，不包含云端转码、账号体系、多设备同步、在线转换、音乐平台下载或远程解析服务。

## 当前版本

当前应用版本来自 `pubspec.yaml`：

```text
1.1.5+3
```

FrameLean 更名后的主要版本事实：

| 版本 | 事实设计说明 |
| --- | --- |
| `v1.0.0` | 完整视频压缩工作台、任务队列、应用设置、macOS / Windows 初始发布 |
| `v1.1.0` | Windows 运行时和进程控制修复、FFmpeg 输出参数优化、项目 workflow 初始规范 |
| `v1.1.5` | 媒体处理扩展、专有音频输入适配、工作台主题和任务排序、仓库结构治理 |

版本事实说明见 `docs/releases/`。

## 当前能力边界

- 视频仍是最完整的处理链路：导入、FFprobe 分析、缩略图、预览帧、推荐方案、自定义目标体积、编码器后端、分辨率、输出格式和任务执行。
- 图片已进入同一任务模型：支持导入、FFprobe 分析、源图缩略图、图片配置面板、格式 / 分辨率 / 质量 / 元数据保留配置和基础 FFmpeg 输出。
- 音频已进入同一任务模型：支持导入、FFprobe 分析、音频占位缩略图、格式 / 码率 / 采样率 / 声道配置和基础 FFmpeg 输出。
- 专有音频输入是导入适配能力：NCM 使用本地 Dart 还原；MGG / MFLAC 等 QMC 变体通过外部适配器或直接放置的 `qmc-decrypt` 运行时处理。
- 工作台支持深浅主题切换，主题偏好保存到 `settings.theme_mode`；`theme_prefs.json` 只作为首帧缓存镜像。

## 架构边界

项目采用接近 Clean Architecture 的分层：

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

- `domain` 保存实体、枚举和值对象，不依赖 Flutter、Drift、FFmpeg、文件系统或平台 API。
- `application` 保存用例、仓储接口和服务抽象，描述应用流程。
- `infrastructure` 实现 Drift、FFmpeg / FFprobe、文件系统、进程控制、平台差异和本地服务。
- `features/workbench` 是 UI 和状态协调层，通过 Riverpod notifier 调用 application 用例。
- `app` 负责入口、主题和路由。

当前架构事实见 `docs/develop/architecture.md`，数据模型见 `docs/develop/data-model.md`。

## 平台边界

| 平台 | 当前状态 |
| --- | --- |
| macOS Apple Silicon | 主要验证和发布平台 |
| Windows x64 | 主要验证和发布平台 |
| Linux | Flutter 工程目录存在，不是当前发布目标 |
| Web | Flutter 工程目录存在，不支持本地 FFmpeg 进程路线 |

## 文档阅读入口

- 文档总入口：`docs/README.md`
- 当前任务：`docs/work/active.md`
- 候选任务：`docs/work/backlog.md`
- 有效决策索引：`docs/work/decisions.md`
- 经验总结：`docs/lessons.md`
- 变更记录：`CHANGELOG.md`
- 项目级 skills：`.agents/skills/README.md`
