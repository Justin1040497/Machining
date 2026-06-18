# FrameLean 项目上下文

## 项目定位

FrameLean（帧轻）是一个本地桌面媒体压缩与格式处理工具。它基于 Flutter Desktop、FFmpeg / FFprobe、Riverpod、Drift 和 SQLite，把常见视频、图片、音频分析、压缩、格式输出配置和任务队列能力封装成图形界面。

项目当前定位是本地桌面应用，不包含云端转码、账号体系、多设备同步、在线转换、音乐平台下载或远程解析服务。

## 当前版本

当前应用版本来自 `pubspec.yaml`：

```text
1.2.1+5
```

FrameLean 更名后的主要版本事实：

| 版本 | 事实设计说明 |
| --- | --- |
| `v1.0.0` | 完整视频压缩工作台、任务队列、应用设置、macOS / Windows 初始发布 |
| `v1.1.0` | Windows 运行时和进程控制修复、FFmpeg 输出参数优化、项目 workflow 初始规范 |
| `v1.1.5` | 媒体处理扩展、专有音频输入适配、工作台主题和任务排序、仓库结构治理 |
| `v1.2.0` | macOS Universal 2 发布链、输出文件名模板和输出配置生效语义、任务完成音效、媒体默认值与保持原始语义、视频色彩与 HDR 转 SDR 边界 |
| `v1.2.1` | 自托管更新客户端体验接入、媒体处理可靠性修复、通知中心和任务夹交互重构：更新入口 / 下载 / helper、自托管服务、图片有效压缩验收、透明视频保留、输出 preflight、批量导入任务夹、任务夹队列顺序 |

版本事实说明见 `docs/releases/`。

## 当前能力边界

- 视频仍是最完整的处理链路：导入、FFprobe 分析、缩略图、预览帧、推荐方案、自定义目标体积、编码器后端、分辨率、输出格式和任务执行。
- 图片已进入同一任务模型：支持导入、FFprobe 分析、源图缩略图、图片配置面板、格式 / 分辨率 / 质量 / 元数据保留配置和基础 FFmpeg 输出。
- 音频已进入同一任务模型：支持导入、FFprobe 分析、音频占位缩略图、格式 / 码率 / 采样率 / 声道 / 元数据保留配置和基础 FFmpeg 输出。
- 媒体任务“保持原始”只是一种任务配置模式：UI 显示真实源格式加 `（保持原始）` 提示，底层仍保存真实 `MediaOutputFormat` 和 `keepOriginalOutputFormat` 布尔值，不引入 `source` 伪格式。
- 图片压缩从 v1.2.1 开始执行结果验收：源格式输出不小于源文件时会清理无效候选并尝试 WebP / JPG fallback；第二次仍无效会失败并保留原因，不再静默产出更大的“成功”文件。
- 透明视频从 v1.2.1 开始按 FFprobe alpha 像素格式自动进入 `透明保留` 策略，输出固定为 MOV + ProRes 4444；目标体积和预设只作为尽力压缩意图。
- 工作台从 v1.2.1 开始把任务夹作为本地持久化实体：批量导入会按媒体类型自动建夹，总列表混排显示任务夹和未入夹任务；任务夹主体打开夹级配置，尾部查看按钮打开左侧内容浮层，夹内任务可按普通任务行启动、暂停、重试、重链、查看日志、排序或移出。
- 工作台任务夹支持批量工作流：未入夹任务可多选后按媒体类型创建任务夹；任务拖拽柄拖到同类型任务夹主体会入夹，拖到任务夹边缘或普通任务上仍按总列表排序；跨类型任务夹在拖起时禁用显示并作为排序目标处理。任务夹尾部主按钮可按夹内状态批量暂停、启动下一项或重试终态任务；空任务夹会自动删除。
- 专有音频输入是导入适配能力：NCM 使用本地 Dart 还原；MGG / MFLAC 等 QMC 变体通过外部适配器或直接放置的 `qmc-decrypt` 运行时处理。
- 工作台支持深浅主题切换，主题偏好保存到 `settings.theme_mode`；`theme_prefs.json` 只作为首帧缓存镜像。
- 应用内通知进入统一通道：设置保存、任务完成 / 失败通过 `AppNotificationManager` 写入本地历史，通知中心展示完整正文和文字按钮组；分析中点击等交互提示只显示临时浮层，不写入通知中心。任务完成不再弹出完成弹窗，但仍播放完成提示音，并在任务项尾部提供打开完成文件位置入口。

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
- `app` 负责入口、主题、路由、共享展示组件和 Riverpod composition root。

当前架构事实见 `docs/develop/architecture.md`，数据模型见 `docs/develop/data-model.md`。

## 平台边界

| 平台 | 当前状态 |
| --- | --- |
| macOS Universal 2（Intel x86_64 + Apple Silicon arm64） | 主要验证和发布平台 |
| Windows x64 | 主要验证和发布平台 |
| Linux | Flutter 工程目录存在，不是当前发布目标 |
| Web | Flutter 工程目录存在，不支持本地 FFmpeg 进程路线 |

## 发布与更新边界

- macOS 发布使用单一 Universal 2 DMG，同时覆盖 Intel x86_64 和 Apple Silicon arm64。
- Windows 发布只覆盖 x64；正式发布入口生成便携 ZIP 和 Inno Setup 安装器。
- Windows 安装器固定为当前用户安装到 `%LOCALAPPDATA%\Programs\FrameLean`，不提供管理员安装切换，避免后续静默覆盖更新触发 UAC。
- 自托管更新客户端只消费 `windows-x64` 和 `macos-universal2` 平台包；Windows 直装版安装器作为 Admin / COS 留存成果物，后续供产品官网分发，不会出现在客户端检查更新或下载 ticket 中。
- 自托管更新客户端从 v1.2.1 开始接入主流程：应用启动自动静默检查一次，设置关于栏可手动检查和启动下载，通知中心按版本去重展示更新通知，工作台顶部在存在更新时持续显示入口。
- Windows 自托管更新由主应用完成下载、断点续传和 SHA-256 校验，再交给随包提供的独立 `FrameLeanUpdaterHelper.exe` 退出应用、执行安装器、检查退出码并重启应用。
- 更新服务端发布前仍处于 `server v1.0.0` / 后端 `v1` 线；v1 线内数据库演进使用 `V*__v1_database_*` 迁移命名，PostgreSQL 保存 release / package / download event 长期数据，Redis 保存短期下载票据、限流计数和 latest cache。

## 文档阅读入口

- 文档总入口：`docs/README.md`
- 当前任务：`docs/work/active.md`
- 候选任务：`docs/work/backlog.md`
- 有效决策索引：`docs/work/decisions.md`
- 经验总结：`docs/lessons.md`
- 变更记录：`CHANGELOG.md`
- 项目级 skills：`.agents/skills/README.md`
