# 更新日志

主要记录 FrameLean 的变化。更名前的历史内容保留在带旧产品版本号的条目中。

历史开发过程、阶段性实现细节和临时决策放在 `docs/archive/logs/`；这里记录每次更新的概要

## 记录格式

```text
YYYY-MM-DD｜vX.Y.Z｜Release 或 No Release
当天更新概要

### Added

- 新增内容

### Changed

- 更新内容

### Fixed

- 修复内容

### Verified

- 验证内容
```

同一天的多个提交会合并整理为简洁 bullet

## 2026-06-07｜v1.1.5｜No Release

今天完成工作台主题和交互体验整理，补齐深浅主题切换、响应式尺寸、任务拖拽排序和相关文档，并修复 QMC 上游 `qmc-decrypt` 构建和运行时探测脚本。

### Added

- 新增 FrameLean 主题 token 和深色配色，工作台顶部栏新增深浅主题切换按钮，主题偏好保存到 `settings.theme_mode`。
- `main()` 启动前读取轻量 `theme_prefs.json` 缓存并注入初始主题，避免等待 SQLite / Drift 初始化完成才确定首帧主题。
- 接入 `flutter_screenutil`，工作台和主题文本按桌面基准尺寸适配，并限制桌面大窗口不放大字体。
- 任务列表新增拖拽手柄，使用 `ReorderableListView` 调整任务顺序并复用现有排序持久化逻辑。
- 设置弹窗顶部媒体类型切换复用任务配置卡中的分段切换组件。
- 新增工作台 UI 刷新、主题切换设计文档，并新增 `ReorderableListView` / `Tooltip` 拖拽布局断言问题日志。
- 新增任务排序 use case、仓储 sort-only 持久化和主题缓存启动自愈的回归测试。

### Changed

- 工作台、任务列表、顶部栏、底部栏、弹窗、通知、表单控件、状态标签、进度条和滑杆颜色统一改为从 `FrameLeanColors` 主题 token 读取。
- 图片质量和视频目标体积分段滑杆在深色主题下使用主色作为圆形拖拽点，避免深色 thumb 与弹窗背景混在一起。
- README、文档入口、技术栈、数据模型和测试计划更新为当前媒体处理、主题切换、schema 15 和测试入口事实。
- 任务执行期间状态轮询间隔从 500ms 延长到 1000ms，并新增 `_taskListHasChanged` 变更检测，仅在任务 id / status / progress 实际变化时触发 UI 更新，避免无变化的无效全量重建。
- 工作台 `syncSelectedTaskIdAfterBuild`、`syncSelectedTaskConfigAfterBuild`、`syncQualityPresetAfterBuild` 从 `build()` 内移到 `ref.listen` 回调中触发，仅在任务列表数据变化时执行，不再随拖拽导入状态、主题切换等无关重建调度 deferred `setState`。
- 深浅主题切换使用 `MaterialApp.router` 内建主题动画参数，交由 Flutter 的 `AnimatedTheme` 处理过渡。
- 队列执行语义改为以任务列表顺序为唯一队列顺序：底部开始按实时列表顺序选择等待中 / 已暂停任务，运行中调整任务顺序会影响后续任务；任务行开始保留插队行为，不修改列表排序。
- 任务排序持久化改为只更新 `sort_order`，避免拖拽排序用旧任务快照覆盖运行中任务的进度、状态、错误或输出路径。
- 工作台任务列表变更监听改为 `listenManual(..., fireImmediately: true)`，预热 `AsyncData` 下也能同步选中任务、配置和质量预设。
- 深浅主题动画交回 `MaterialApp.router` 的 `themeAnimationDuration` / `themeAnimationCurve`，不再手写 `ThemeData.lerp` 包装层。
- 主题启动缓存明确为 `theme_prefs.json` 首帧镜像；启动后异步读取 DB，并以 `settings.theme_mode` 为准更新应用主题和重写缓存。
- `.claude/settings.local.json` 从共享提交中移除，并加入 `.gitignore` 作为本机配置。

### Fixed

- 修复 `ReorderableListView` 拖拽任务项时，任务行内部 `Tooltip` / `OverlayPortal` 在拖拽 overlay 重挂载期间触发 `_RenderLayoutBuilder was mutated in _RenderLayoutBuilder.performLayout` 的问题；拖拽列表项内关闭 tooltip wrapper，并用 `Semantics` 保留无障碍标签。
- 修复 macOS / Windows `qmc-decrypt` 构建脚本误用 `--version` 导致构建后验证失败的问题；当前锁定的上游 CLI 只支持 `--help` 探测。
- 修复直接使用上游 `qmc-decrypt` 时的运行时可用性探测和文档契约，避免把 FrameLean wrapper 的 `--version` 要求错误套到上游二进制。
- 修复任务拖拽排序松手后，被移动任务及其之间的所有任务项预览图和标题闪烁的问题；根因是 `reorderTasks` 异步等待 DB 持久化后才更新 state，与 `ReorderableListView` 期望的同步数据更新产生时序冲突，改为乐观更新：先从内存 state 计算重排结果立即更新 UI，再异步持久化到 DB。
- 修复底部暂停按钮文案为“暂停所有任务”但实际逐个调用单任务暂停、可能触发队列继续执行的问题；底部暂停现在只暂停当前执行上下文并停止自动续跑。
- 修复拖拽排序后台持久化失败会变成未处理异步错误的问题；页面现在捕获失败并提示，notifier 会刷新仓储顺序恢复一致性。

### Verified

- 通过 `dart analyze lib/`。
- 通过 `git diff --check`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/bundled_proprietary_audio_adapter_registry_test.dart`。
- 通过 `scripts/build/build_qmc_decrypt_macos_arm64.sh`。

## 2026-06-06｜v1.1.5｜No Release

今天完成仓库根目录结构治理，作为 `feature/media-processing` 的工程整理内容。

### Changed

- 将根目录 `NOTICE` 移入 `legal/NOTICE.md`，保留根目录 `LICENSE` 作为项目许可证发现入口。
- 将构建和发布脚本拆分到 `scripts/build/` 与 `scripts/release/`。
- 将本地参考、临时样本和工具状态迁入 `.workspace/`，并通过 `.gitignore` 排除。
- 更新 macOS / Windows 打包路径和法律材料复制配置。
- 扩展常规媒体输入格式识别，覆盖更多视频、图片和音频扩展名。
- 图片导出新增 BMP、TIFF、GIF；音频导出新增 AIFF、WMA、Opus 和 Ogg Opus。
- 新增本地专有音频导入适配边界：NCM 使用 Dart 原生还原，MGG / MFLAC 通过 QMC 外部适配器运行时处理，并兼容直接放置 `qmc-decrypt`。
- macOS 内置 FFmpeg 构建脚本新增 `libmp3lame`、`libwebp`、`libopus` 静态构建和启用参数；macOS / Windows 发布脚本会校验关键编码器是否存在。
- 统一任务配置百分比滑杆样式：视频目标体积右侧显示 `压缩体积XX%`，图片质量复用分段百分比滑杆并显示 `保留XX%的质量`。

### Fixed

- 音频 MP3 输出会在命令构造阶段检查当前 FFmpeg 是否支持 `libmp3lame`，避免任务启动后才暴露 `Unknown encoder 'libmp3lame'`。
- 图片 WebP 输出会在命令构造阶段检查当前 FFmpeg 是否支持 `libwebp`，避免发布包运行时缺编码器才失败。

### Verified

- 通过 `git diff --check`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart`。
- 通过 `flutter test test/widget_test.dart test/app_settings_dialog_test.dart`。

## 2026-06-05｜v1.1.5｜No Release

今天拆分 FrameLean 项目级 workflow skills，降低单次 commit、PR、release 文案和测试计划请求的上下文负担。

### Added

- 新增 `framelean-feature-analysis`、`framelean-feature-design`、`framelean-feature-tasks`、`framelean-test-plan`、`framelean-implementation`、`framelean-review` 和 `framelean-delivery` 项目级 skills。
- 新增 `.agents/skills/README.md`，说明 FrameLean 项目级 skills 的触发场景、推荐流程和文档位置约定。
- 新增媒体处理扩展首个实现切片：`MediaTaskConfig`、视频 / 图片 / 音频分类型配置和通用输出格式。
- Drift schema 升级到 14，新增任务通用配置 JSON、图片分析字段和设置表预留的默认媒体配置 JSON 字段。
- 设置仓储启用 `default_media_config_json` 读写，并保留旧视频默认字段兼容。
- 应用设置弹窗支持保存默认视频、图片和音频处理配置。
- FFprobe 支持纯音频和静态图片分析；FFmpeg 命令规划支持图片和音频基础输出计划。

### Changed

- 将 `framelean-workflow` 改为轻量路由入口，按请求路由到功能分析、设计、任务、测试计划、实现、审查验证或交付收尾 skill。
- 将 API 测试链规范改造为 FrameLean 测试计划 skill 的可选 API/服务端测试章节，普通桌面应用功能测试项优先来自 `docs/develop/test-plan.md`。
- 将 commit 详情、PR 描述、release description、changelog、bug log 和功能网归档收敛到 `framelean-delivery`。
- 文档入口补充 `docs/features/` 的功能级分析、设计、任务、测试计划和功能网归档用途。
- 导入、文件选择、输出路径、完成弹窗、关于弹窗和任务空态文案从视频专用表述收敛为通用媒体处理表述。
- 图片任务使用步骤型进度和源图缩略图；音频任务输出命令使用 `-vn` 禁用视频流。
- 图片任务配置面板显示图片格式、分辨率、质量和保留元数据开关；质量默认 100%，默认不保留元数据，图片编码由后台按格式推导。
- 更新媒体处理设计、任务、测试计划、数据模型、架构、技术栈、测试计划和路线图文档，明确图片 / 音频配置面板能力和剩余默认设置边界。

### Verified

- 通过 Ruby YAML 解析检查全部 `framelean-*` skill frontmatter。
- 通过 Ruby YAML 解析检查全部 `agents/openai.yaml`。
- 通过 `git diff --check`。
- 通过 `dart run build_runner build --delete-conflicting-outputs`。
- 通过当前变更 Dart 文件的 `dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。

## 2026-06-04｜v1.1.5｜No Release

调整关于弹窗的项目仓库入口，并删除托管更新联调实现。

### Added

- 关于弹窗底部左侧新增 GitHub 和 Gitee 图片图标入口。

### Changed

- 移除关于弹窗标题栏右侧 GitHub 图标和底部左侧“检查更新”按钮。
- GitHub / Gitee 项目入口统一使用系统外链打开逻辑。
- 基于当前系统设计尚未稳定、域名备案相关准备尚未完成，删除客户端更新检查、更新包下载、托管更新服务联调代码和本地 Release 探测脚本。
- 删除 `server/` 后端实验目录，并移除 `.gitignore` 中对 `/server/` 的忽略规则。
- 清理当前开发文档中的托管更新服务、接口、构建参数和验证说明。

### Verified

- 通过 `flutter pub get`。
- 通过 `dart format lib/features/workbench/pages/workbench_page.dart lib/application/services/framelean_build_info.dart lib/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart test/app_settings_dialog_test.dart test/workbench_about_dialog_test.dart`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `git diff --check`。

## 2026-06-03｜v1.1.5｜No Release

今天统一需求完成后的最终交付包，并继续推进自托管更新前端下载和安装包打开交互。

### Added

- 新增更新包下载器抽象和 HTTP 实现，支持下载进度、`.part` 临时文件、SHA-256 校验和失败清理。
- “发现新版本”弹窗新增下载更新、下载进度、下载完成、显示文件、打开 DMG 和 Windows 安装器启动交互。
- 新增更新会话申请接口，客户端使用本地安装 ID 换取短期更新 Token。
- 新增本地安装 ID 持久化和服务端下载事件记录 / 重复下载限流。
- 新增更新包下载器单元测试和更新弹窗下载 / 安装交互 widget 测试。

### Changed

- `framelean-workflow` Gate 6 改为要求在文档、changelog、同步和验证完成后始终输出 commit 详情和详细 PR 文案。
- PR description 固定使用中文标题：变更概览、背景与目标、实现详情、验证结果、风险与回滚、文档与变更记录、评审重点。
- Release description 固定使用中文标题：版本摘要、主要变更、验证与兼容、发布产物、已知风险、升级与回滚说明、关联记录。
- 项目 workflow 和 Git workflow 文档同步记录最终交付包、commit 详情和固定模板要求。
- 自托管更新文档补充客户端下载、校验、保存目录、打开安装包和手动验证边界。
- 更新服务鉴权从 HMAC 请求签名改为短期更新会话 Token，客户端不再内置静态 `FRAMELEAN_UPDATE_TOKEN`。

### Fixed

- 加固 FFmpeg 队列 runner 异步测试等待逻辑，避免默认并发全量测试中后台观测收尾尚未完成就断言任务状态。

### Verified

- 通过 `flutter test test/app_update_package_downloader_test.dart test/update_available_dialog_test.dart`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `cargo fmt --manifest-path server/update-service/Cargo.toml --check`。
- 通过 `cargo test --manifest-path server/update-service/Cargo.toml`。
- 通过 `git diff --check`。

## 2026-05-29｜v1.1.5｜No Release

今天开始自托管更新能力的第一阶段实现，先接入关于入口和客户端更新检查骨架，并清理旧的第三方 Release 更新源。

### Added

- 首页白色安全区新增关于入口，关于弹窗提供 GitHub 项目入口和检查更新入口。
- 新增应用版本比较、自托管更新接口解析和 macOS DMG 更新信息识别。
- 新增 Rust 自有更新服务，提供版本检查、版本日志、平台包信息和短期签名下载接口。
- 新增更新接口 HMAC 请求签名，客户端持久化安装级 client id 并为每次请求生成 nonce。
- 检查更新失败时对用户显示统一重试提示，内部保留 HTTP 状态码、TLS 握手失败、连接超时和 DNS 解析失败等诊断细节。

### Changed

- `http` 作为直接依赖用于更新检查请求。
- `crypto` 作为直接依赖用于更新接口 HMAC-SHA256 请求签名。
- 检查更新从 GitHub / Gitee Releases 改为请求自建更新接口，并通过 `FRAMELEAN_UPDATE_BASE_URL` 和 `FRAMELEAN_UPDATE_HMAC_SECRET` 配置接口地址和签名密钥。
- 发布流程文档移除 Cloudflare Workers / R2 更新源说明，后续改为自有服务器托管。

### Fixed

- 移除 GitHub / Gitee Release 同步 Action 和脚本，避免更新包同步流程受第三方 Release 上传速度影响。
- 移除 Cloudflare Worker / R2 更新后端残留，避免和后续 Rust 自有服务器实现并存。

### Verified

- 通过 `cargo fmt --manifest-path server/update-service/Cargo.toml --check`。
- 通过 `cargo test --manifest-path server/update-service/Cargo.toml`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `git diff --check`。

## 2026-05-29｜v1.1.5｜Release

今天完成 v1.1.5 发布准备，统一应用版本、macOS / Windows 发布产物命名、Windows zip 解压目录和 changelog 记录格式。

### Changed

- 将应用版本升级为 `v1.1.5`。
- macOS DMG 产物改为按 `pubspec.yaml` 语义化版本生成 `FrameLean-v1.1.5.dmg`。
- Windows zip 产物保持 `FrameLean-v1.1.5-windows-x64.zip`，并在压缩包内使用 `FrameLean-v1.1.5-windows-x64/` 作为顶层目录。
- release policy、Git 工作流和 changelog 记录规则统一为日期、版本号、Release 状态三段式格式。

### Verified

- 通过 `bash -n scripts/build_dmg_macos.sh`。
- 通过 `git diff --check`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `scripts/build_dmg_macos.sh`，生成并校验 `build/macos/Build/Products/Release/FrameLean-v1.1.5.dmg`。

## 2026-05-28｜v1.1.5｜No Release

今天主要完成 Windows 窗口行为、iPhone MOV 兼容、执行日志和设置即时生效修复，作为 v1.1.5 发布候选内容。

### Changed

- Windows 启动窗口改为按主屏幕工作区居中显示。
- Windows 管理员模式启动时显示拖拽限制提示，并提供“普通模式重启”操作。
- 压缩完成弹窗简化为小型结果弹窗，只展示压缩前后体积、单行可复制导出路径、取消和打开文件存放位置。
- FFprobe 分析结果新增可转码主音频流索引，FFmpeg 命令从映射所有音频流改为映射单个可用音频流。
- 自动编码后端在 Apple HDR / HVC1 / 10-bit MOV 等高风险源上优先使用可用的软件编码；显式选择 VideoToolbox 时仍尊重用户选择。
- 音频输出默认使用 FFmpeg 原生 `aac`，不再默认优先 `aac_at`。

### Fixed

- 修复 macOS / Windows 大小写不敏感文件系统上，大写 `.MOV` 源文件可能因输出路径只差大小写而触发 FFmpeg 原地覆盖失败的问题。
- FFmpeg 执行失败时保留 stderr 尾部错误信息，避免只显示退出码导致 MOV 压缩失败原因不可见。
- 修复 iPhone MOV 中 Apple Positional Audio / APAC 被 `-map 0:a?` 一起映射后，FFmpeg 因 `none` 音频流无解码器而失败的问题。
- 修复执行日志写入任务实体后又被任务状态保存覆盖，导致失败后日志窗口为空的问题；日志窗口现在读取临时 FFmpeg 日志文件。
- 修复应用设置保存后仅对新导入任务生效、已有任务不更新默认配置的问题；现在设置保存时会立即更新所有待处理（pending / failed / cancelled）任务的压缩配置。

### Verified

- 通过 `dart run build_runner build --delete-conflicting-outputs`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/ffmpeg_command_builder_test.dart test/ffprobe_media_analyzer_test.dart test/ffmpeg_task_queue_runner_test.dart test/ffmpeg_process_observer_test.dart test/widget_test.dart`。
- 通过 `flutter test test/file_extension_media_kind_resolver_test.dart test/ffmpeg_command_builder_test.dart test/ffmpeg_process_observer_test.dart`。
- 通过 `flutter test test/widget_test.dart`。

## 2026-05-27｜v1.1.0｜Release

今天主要完成 Windows 桌面兼容修复、FFmpeg 输出参数优化、Windows 发布包自动化和 zip 布局修复，并将全局字体、项目级 workflow 和 `v1.1.0` 发布准备纳入本次发布。

### Added

- 新增 FFprobe 分析字段，覆盖像素格式、位深、色彩范围、色彩矩阵、传递曲线、色彩原色、帧率、宽高比、旋转、场序和音频声道布局。
- 新增 FFmpeg 命令构造能力，包含显式视频 / 音频流映射、BT.709 SDR 输出色彩标签、Lanczos 缩放、SAR 归一化、音频声道 / 采样率输出和 AudioToolbox AAC 优先策略。
- 新增 FFmpeg 进程控制抽象，由 application 层定义暂停、继续和终止能力，infrastructure 层负责具体平台实现。
- 新增 Windows runner 原生进程控制通道，通过线程挂起和恢复支持 Windows 上的 FFmpeg 真暂停 / 继续。
- 已完成任务新增“重来”入口，任务列表和完成弹窗都可以从源文件检查和媒体分析重新开始。
- 新增 GitHub Actions Windows 打包 workflow，可在 Windows runner 上恢复 FFmpeg 运行时并调用 `scripts\release\build_windows.ps1` 生成发布 zip。
- 新增 `docs/develop/project-workflow.md` 和 `.agents/skills/framelean-workflow/`，记录 FrameLean 项目级需求、分支、测试、实现、验证和 PR 准备流程。

### Changed

- 将应用版本升级为 `v1.1.0`，同步发布文档、路线图、Windows 产物示例路径和 Windows 版本 fallback。
- 将应用全局字体切换为 Alibaba PuHuiTi，并接入 Regular、Medium、SemiBold 和 Bold 四个字重资源。
- 压缩输出默认通过滤镜链统一到 `yuv420p`、limited range、BT.709，并避免分辨率预设把小尺寸源视频向上放大。
- VideoToolbox HDR 源素材优先使用 `scale_vt` 转为 SDR BT.709 输出。
- Drift `tasks` schema 升级到 12，用于持久化新增 FFprobe 分析字段。
- 队列执行器不再直接依赖 `ProcessSignal`，暂停、继续和取消统一通过 `FfmpegProcessController` 调用。
- Windows 工作台顶部新增通知安全区，顶部通知会显示在安全区内，避免遮挡任务列表第一项操作按钮。
- Windows 打包脚本改为逐文件写入 zip，并强制使用标准 `/` 路径分隔符；打包完成后校验关键运行时和核心文件布局。
- Windows FFmpeg 依赖 zip 和校验文件现在作为本地 / Release 资源处理，避免误提交到源码仓库。
- 项目 agent 规则从 Git-only skill 迁移到 `framelean-workflow`，并更新 `AGENTS.md`、`CLAUDE.md` 和文档入口。

### Fixed

- 修复 Windows 点击暂停后再继续时进度条卡住、任务不再完成的问题。
- 修复任务完成后缺少清晰“重来”操作的问题。
- 修复单任务列表场景下顶部通知遮挡第一项右侧按钮的问题。
- 修复 Windows 打开文件所在位置时，包含空格或中文的路径可能被 Explorer 解析失败的问题。
- 修复 Windows 发布 zip 内部条目使用反斜杠路径，可能导致解压后 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe` 不在应用可识别目录的问题。

### Verified

- 通过 `flutter pub get`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/workbench_file_revealer_test.dart`。
- 通过 `flutter test test/ffprobe_media_analyzer_test.dart test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart`。
- 通过 workflow YAML 解析检查、旧 skill 路径引用扫描、尾随空白检查和 `git diff --check`。
- 通过 `unzip -l /Users/leftzhou/Downloads/FrameLean-v1.0.0-windows-x64.zip` 复现旧包中存在 `ffmpeg\ffmpeg.exe` 条目。
- 通过 GitHub Actions 日志确认旧脚本缺少 `System.IO.Compression` 类型加载。

## 2026-05-26｜v1.0.0｜Release

今天完成 FrameLean 更名后的 v1.0.0 桌面视频压缩发布。

### Added

- 提供完整的视频压缩工作流，支持拖拽或选择导入视频、分析源文件信息、配置压缩参数并执行任务。
- 支持推荐方案和自定义目标体积两种压缩方式，可展示预计输出大小、目标视频码率和目标音频码率。
- 支持输出格式、视频编码、分辨率、输出目录和输出文件名配置。
- 支持任务队列、进度显示、暂停、继续、取消、删除、重命名和完成后打开输出位置。
- 支持压缩前后预览帧、视频缩略图和任务状态展示。
- 支持应用设置弹窗，可配置默认压缩方案、默认导出地址、默认导出文件名和自定义 FFmpeg / FFprobe 路径。
- 提供 macOS Apple Silicon 和 Windows x64 发布包。

### Changed

- 统一产品显示名为 FrameLean，中文名为帧轻。
- 统一内部包名、应用标识、平台元数据、构建脚本、发布产物名称和法律资料。
- 完善 Git 工作流和 agent 提交规则，要求每次提交前记录 changelog，bug 修复同步补充归档日志。
- 补充分支创建失败诊断规则，区分真实 ref 路径冲突和沙盒或权限导致的 `.git` 写入失败。

### Fixed

- 修复推荐方案自动改变视频分辨率的问题。
- 修复自动编码后端选择失效的问题。
- 修复已压缩任务仍显示目标体积预估的问题。
- 修复部分缓存状态导致任务显示或配置刷新不及时的问题。
- 修复 Windows 导入部分 MP4 后 FFprobe 全量 JSON 元数据触发字符串转义解析失败的问题。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 macOS DMG 打包验证。

## 2026-05-26｜Machining v1.5.0+1｜No Release

今天主要整理分层架构、工作台交互和弹窗风格，作为旧 Machining 阶段的未发布开发记录。

### Added

- 新增 Application Use Cases，覆盖应用设置、任务导入、分析、恢复、重试、排序、队列启动、单任务开始 / 暂停 / 继续、删除、清空和预览帧生成。
- 新增持久化兼容层和 `CompressionModeMapper`，把历史 `smart`、`quality` 压缩模式映射到当前 `preset`。
- 新增 `flutter_animate` 依赖，用于工作台右上角通知的进入和退出动画。
- 新增工作台统一弹窗基础组件和弹窗风格测试。

### Changed

- Application 服务按 `input_runtime`、`ffmpeg_planning`、`execution` 分组，UI 状态入口通过 Use Cases 进入业务流程。
- Infrastructure provider 按数据库、仓储、输入运行时、FFmpeg 规划和执行拆分。
- FFmpeg 命令构造拆分为输出路径、编码器解析、视频参数、命令步骤、日志提示和格式化 helper。
- features/workbench 拆分为页面入口、layout、dialogs、overlays、configuration、form controls 和 media task list 组件。
- 压缩模式文案调整为“推荐方案选项”和“自定义目标体积”，数据库当前写入值调整为 `preset` / `targetSize`。
- 任务配置弹窗中的“已修改”“已压缩”移到底部按钮同排左侧显示。

### Fixed

- 修正未实质改变配置时仍显示“已修改”的判断。
- 统一压缩确认、导入失败、清空任务和重命名弹窗的视觉风格，移除生产代码中的默认 `AlertDialog`。
- 移除已废弃的项目参考对比 HTML 文档引用。

## 2026-05-20｜Machining v1.5.0+1｜Release

今天主要完成旧 Machining 阶段的应用设置、发布准备、运行时打包和许可证分发整理。

### Added

- 增加 Windows x64 运行时打包和基础兼容支持。
- 增加 macOS / Windows GPU 编码能力检测，支持自动选择可用编码后端。
- 新增视频缩略图生成能力，并接入任务列表和配置界面。
- 新增智能压缩预设：均衡推荐、微信发送、清晰优先、体积优先。
- 新增目标体积压缩能力，可根据目标大小和视频时长估算压缩码率。
- 新增压缩结果预估，展示预计输出大小、目标视频码率和目标音频码率。
- 新增应用设置弹窗，支持默认压缩方案、默认导出地址、默认导出文件名、自定义 FFmpeg / FFprobe 路径和高级设置。
- 新增应用设置持久化字段，新任务会读取默认输出目录、智能压缩预设、输出编码和文件名模板。
- 新增 GPLv3+、第三方声明、源码获取说明、FFmpeg 构建信息和 macOS DMG 打包验证脚本。

### Changed

- 重构主界面，将顶部栏、底部栏、任务列表、预览区、文件信息、导出路径和配置面板拆分为独立模块。
- 重构任务详情设置弹窗，集中配置输出格式、编码、分辨率、压缩模式和输出文件名。
- 将目标体积模式调整为比例滑杆，降低手动输入成本。
- 完善缺失源文件重新指定流程。
- 将“在 Finder 中打开”调整为跨平台的“打开文件所在位置”。
- 将工作台通知改为顶部浮层，避免遮挡底部操作按钮。
- 移除未完成的 `/settings` 占位路由；应用设置现在从工作台弹窗打开。
- 将格式检查调整为只处理 Git 跟踪的 Dart 文件，避免误改本地工作树目录。
- 更新 macOS / Windows 发布资料复制和内置 FFmpeg 验证路径。
- 同步 README、文档中心、路线图、技术栈、数据模型和许可证分发文档中的版本事实。

### Fixed

- 修复默认压缩会改变视频分辨率的问题，推荐预设不再自动调整分辨率。
- 修复默认 CPU / GPU 编码选择失效的问题，默认编码后端恢复为自动选择。
- 修复已压缩任务仍显示目标体积预估的问题。
- 修复压缩完成弹窗内容展示异常，并优化输出文件路径和打开位置操作。
- 修复部分缓存状态导致任务显示或配置刷新不及时的问题。
- 排除 `worktrees/` 目录，避免其他工作树影响当前分支的静态分析结果。
- 移除设置页占位路由，避免发布版本暴露未完成页面。

### Verified

- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 macOS DMG 打包测试。

## 2026-05-15｜Machining v1.3.0+1｜No Release

今天主要重构主界面和压缩配置相关代码，并修复一批已知交互问题。

### Added

- 添加应用图标资源，并更新 macOS / Windows 图标配置。
- 新增智能压缩预设、压缩模式和压缩结果预估能力。
- 补充压缩预估、编码器能力、分辨率预设和 FFmpeg 命令生成相关测试。

### Changed

- 重构主界面代码，将顶部栏、底部栏、任务列表、预览区、文件信息、导出路径和配置面板拆分为独立模块。
- 重构任务详情设置弹窗，优化压缩参数配置体验。
- 完善 FFmpeg 编码器能力判断、命令生成、任务执行和进度观测逻辑。
- 将“在 Finder 中打开”调整为跨平台的“打开文件所在位置”。

### Fixed

- 修复压缩完成弹窗内容展示异常，并优化输出文件路径和打开位置操作。
- 将工作台通知改为顶部浮层，避免 SnackBar 遮挡底部操作按钮。
- 修复默认压缩会改变视频分辨率的问题，推荐预设不再自动调整分辨率。
- 修复默认 CPU / GPU 编码选择失效的问题，默认编码后端恢复为自动选择。

## 2026-05-14｜Machining v1.2.0+1｜No Release

今天主要完成主界面重构、视频缩略图能力和文档目录整理。

### Added

- 新增视频缩略图生成能力，并接入任务列表和配置相关界面。
- 新增文档入口和目录 README。

### Changed

- 更新为更轻便的主界面视觉风格。
- 优化任务配置窗口打开方式和应用窗口顶部样式。
- 整理文档目录结构，拆分产品、架构、开发、功能、参考资料和历史归档。
- 将历史开发日志迁移到 `docs/archive/logs/`。

## 2026-05-07｜Machining v1.1.0+1｜No Release

今天主要推进 Windows 兼容、GPU 编码能力和运行时资源配置。

### Added

- 增加 Windows 运行时打包和基础兼容支持。
- 为 macOS 和 Windows 增加 GPU 编码加速相关支持。
- 新增 FFmpeg 编码器能力检测接口。

### Changed

- 调整 FFmpeg 定位、命令构建、任务执行和预览帧生成逻辑，以适配不同平台和编码器后端。
- 更新 Windows 入口、窗口行为和运行时资源配置。
- 更新 README 和 Windows 运行时打包说明。

## 2026-05-06｜Machining v1.0.0+1｜Release

今天初始化旧 Machining 阶段的核心视频压缩应用、工程结构和基础文档。

### Added

- 提供完整的视频压缩工作流，支持拖拽或选择导入视频并自动分析视频信息。
- 支持生成压缩前后预览帧。
- 支持配置输出格式、编码方式、分辨率、压缩质量、输出目录和文件名。
- 支持任务队列处理、进度显示、暂停、继续、取消、删除和重命名。
- 支持任务完成后直接在 Finder 中打开输出位置。
- 内置 macOS arm64 FFmpeg / FFprobe，支持 libx264 编码，不依赖 Homebrew。
- 初始化 Machining v1.0.0 核心功能和 Flutter 桌面应用基础结构。
- 实现本地媒体任务、应用设置、任务队列和 SQLite 持久化。
- 接入 FFprobe 媒体分析、预览帧生成、FFmpeg 压缩命令构建和进程观测。
- 支持 H.264 / HEVC、输出格式、分辨率、任务状态和压缩配置等核心模型。
- 增加命令行验证入口和 macOS arm64 FFmpeg 构建脚本。
- 初始化产品、需求、设计、架构、测试、路线图和开发日志文档。
- 增加核心服务测试和基础 Widget 测试。
