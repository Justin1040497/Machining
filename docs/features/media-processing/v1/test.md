# media-processing — 测试计划

本测试计划基于 `docs/develop/test-plan.md`、`design.md` 和 `tasks.md`。它描述实现阶段应新增或更新的验证范围；当前阶段不新增测试代码、不运行验证命令。

## 0. 当前验证状态（2026-06-05）

本次首个实现切片已完成以下自动化验证：

- `dart run build_runner build --delete-conflicting-outputs`
- `dart format --set-exit-if-changed`（当前变更 Dart 文件）
- `flutter analyze`
- `flutter test`
- 聚焦测试：`ffprobe_media_analyzer_test.dart`、`ffmpeg_command_builder_test.dart`、`drift_media_task_repository_test.dart`、`ffmpeg_process_observer_test.dart`、`file_extension_media_kind_resolver_test.dart`、`widget_test.dart` 等。

仍未完成的验证：

- macOS / Windows 发布包级构建和手动端到端处理验证。
- 设置默认媒体配置读写、应用设置三类默认处理配置 UI 已接入自动化测试。

## 1. 测试目标

- 验证 FrameLean 从视频专用链路扩展到视频 / 图片 / 音频本地媒体处理后，旧视频导入、分析、配置、执行、完成弹窗和输出路径行为不回退。
- 验证 `MediaTask.config` 从 `VideoTaskConfig` 泛化为 `MediaTaskConfig` 后，domain 不变量、默认配置、仓储映射、Drift 迁移和 UI 状态仍一致。
- 验证图片导入、FFprobe 分析、FFmpeg 命令规划、步骤型进度、缩略图和输出文件可用。
- 验证音频导入、FFprobe 分析、FFmpeg 命令规划、时长型进度、稳定占位缩略图和输出文件可用。
- 验证主链路命名和用户可见文案从“视频 / 压缩”收敛为“媒体 / 处理”，但不暗示首版未实现的音频编辑、波形预览、多轨或云端能力。
- 验证 macOS 和 Windows 的内置 FFmpeg / FFprobe、构建产物和手动处理链路仍可工作。

测试数据建议：
- 视频：`.mp4`、`.mov`、`.mkv`，至少包含一个 iPhone HDR / HVC1 / 10-bit MOV 和一个带 APAC / `none` 音频流的 MOV。
- 图片：`.jpg`、`.png`、`.webp`，至少包含一张带 EXIF 方向信息的 JPEG、一张透明 PNG、一张大尺寸图片。
- 音频：`.mp3`、`.m4a`、`.aac`、`.wav`、`.flac`，至少包含一段有 duration 的纯音频文件。
- 异常样例：不支持扩展名、缺失源文件、同名输出路径冲突、无可用 FFprobe 信息的损坏文件。

## 2. 自动化测试项

| 测试项 | 测试文件/命令 | 覆盖行为 | 备注 |
| --- | --- | --- | --- |
| 静态分析 | `flutter analyze` | 所有 Dart/Flutter 改动无 analyzer error；新命名、导入、provider 注入无断链 | 实现完成后必跑 |
| 全量测试 | `flutter test` | 所有单元测试和 widget 测试通过 | 实现完成后必跑 |
| Domain 配置不变量 | `test/media_task_config_test.dart` | `MediaTaskConfig` 按 `MediaKind` 要求对应 `video` / `image` / `audio` 配置；`MediaTask.draft` 默认配置合法；无效组合失败 | 新增测试文件 |
| 视频配置兼容 | `test/media_task_config_test.dart`、`test/ffmpeg_command_builder_test.dart` | 旧 `VideoTaskConfig.initial()` 默认行为迁移到 `MediaTaskConfig.video` 后不变；视频 CRF、preset、target size、输出命名不回退 | 视频测试先作为回归基线 |
| App settings 默认媒体配置 | `test/app_settings_test.dart`、`test/app_settings_use_cases_test.dart`、`test/app_settings_dialog_test.dart`、`test/media_task_use_case_helpers_test.dart` | 旧视频默认设置可生成通用默认视频配置；新默认媒体配置优先；图片 / 音频默认配置会进入导入初始配置；设置弹窗可保存视频 / 图片 / 音频默认配置 | 覆盖 `defaultMediaConfig`、兼容 getter 和 UI 保存路径 |
| 设置仓储兼容 | `test/drift_app_settings_repository_test.dart` | `default_media_config_json` 读写；旧 `default_output_video_codec` 等字段 fallback；保存时兼容期继续写旧字段 | 与 Drift schema 14 同步 |
| 扩展名识别 | `test/file_extension_media_kind_resolver_test.dart` | 大小写扩展名可解析为 video / image / audio；不支持扩展名仍失败 | 当前只测 `.MOV`，需扩展图片 / 音频样例 |
| 导入 use case | `test/media_task_execution_use_cases_test.dart` 或新增 `test/import_media_task_use_case_test.dart` | video / image / audio 导入不在 import 阶段被拒绝；不支持扩展名保持失败；初始 config 按类型生成 | 覆盖 `ensureSupportedImportedMediaKind` 和初始配置 helper |
| 重新指定源文件 | `test/media_task_execution_use_cases_test.dart` 或新增 `test/replace_missing_source_use_case_test.dart` | 同类型源文件可替换并重新分析；跨类型替换失败；替换后保留任务配置 | 防止音频替换视频任务 |
| Notifier 与状态恢复 | `test/media_task_notifier_test.dart` | 历史任务加载、缺失源文件、指纹变化、根据 settings 创建 draft 对三类媒体都稳定 | 当前测试依赖 `VideoTaskConfig`，实现后迁移为 `MediaTaskConfig` |
| Drift task JSON 映射 | `test/drift_media_task_repository_test.dart` | 视频 / 图片 / 音频 `media_config_json` 可保存和读回；枚举使用稳定字符串；旧视频列 fallback；保存时兼容期继续写旧视频列 | 重点覆盖 schema 13 -> 14 升级 |
| Drift 图片分析字段 | `test/drift_media_task_repository_test.dart` | `analysis_image_width`、`analysis_image_height`、`analysis_image_codec`、`analysis_image_pixel_format`、`analysis_image_bit_depth` 映射正确 | 不破坏已有视频 / 音频分析字段 |
| FFprobe 参数 | `test/ffprobe_media_analyzer_test.dart` | `buildArguments` 包含视频、图片、音频需要的 `format` 和 `stream` 字段；不退回 `-show_streams` 全量输出 | 保持当前精简查询策略 |
| FFprobe 视频回归 | `test/ffprobe_media_analyzer_test.dart` | 视频宽高、编码、码率、HDR、旋转、主音频流选择仍正确；APAC / `none` 音频流仍忽略 | 旧视频分析能力必须保住 |
| FFprobe 纯音频 | `test/ffprobe_media_analyzer_test.dart` | 没有视频流时不失败；可解析 audio codec、bitrate、channels、sample rate、duration、container format | 覆盖 `durationMs` 为空和存在两种情况 |
| FFprobe 静态图片 | `test/ffprobe_media_analyzer_test.dart` | 没有 duration 时仍返回部分 `MediaAnalysisResult`；可解析图片宽高、codec、pixel format、bit depth、orientation | 图片任务不能卡在分析失败 |
| FFmpeg 视频命令回归 | `test/ffmpeg_command_builder_test.dart` | 现有视频压缩、转封装、两遍目标体积、硬件编码降级、主音频流映射、`+faststart` 不变 | 迁移到 `MediaCommandBuilder` 后保留旧断言 |
| FFmpeg 图片命令 | `test/ffmpeg_command_builder_test.dart` 或新增 `test/media_command_builder_test.dart` | JPEG / WebP 质量参数、PNG 参数、长边缩放、输出格式、路径冲突处理、`ProgressMode.step` | 不要求 duration |
| FFmpeg 音频命令 | `test/ffmpeg_command_builder_test.dart` 或新增 `test/media_command_builder_test.dart` | `-vn`、`-c:a`、`-b:a`、`-ar`、`-ac`、输出格式和路径冲突处理正确 | 防止输出带视频流 |
| 进度观测 | `test/ffmpeg_process_observer_test.dart` | `ProgressMode.timed` 使用 `out_time_ms / duration`；`ProgressMode.step` 不依赖 duration；失败和输出文件缺失仍正确 | 当前时长缺失测试应扩展为 step 模式 |
| 队列执行 | `test/ffmpeg_task_queue_runner_test.dart` | 图片步骤型任务、音频时长型任务、视频多步骤任务都能串行执行、暂停、取消、失败写回 | 继续保留临时日志行为 |
| 缩略图服务 | `test/video_thumbnail_generator_test.dart` 或新增 `test/media_thumbnail_generator_test.dart` | 视频继续抽非黑帧；图片生成或返回可用缩略图；音频返回稳定占位；失败缓存不反复生成 | `VideoThumbnailGenerator` 迁移为视频内部实现 |
| 预览服务回归 | `test/generate_preview_frames_use_case_test.dart`、`test/preview_frame_generator_test.dart`、`test/workbench_preview_notifier_test.dart` | 视频预览仍可用；图片 / 音频首版不触发未实现的预览链路；参数变化后预览失效逻辑仍正确 | 音频波形不在本轮覆盖 |
| Workbench 文件选择 | `test/widget_test.dart` 或新增轻量 widget / unit 测试 | `WorkbenchConstants` 暴露视频、图片、音频类型组；`pickMediaFiles()` 命名迁移后调用路径不丢失 | 文件选择器本身可用 mock 或常量检查 |
| 配置弹窗 widget | 新增或扩展 `test/task_configuration_dialog_test.dart` | video task 显示视频配置；image task 显示图片格式 / 分辨率 / 质量 / 元数据开关；audio task 显示格式 / 码率 / 采样率 / 声道 | 覆盖保存按钮和“已修改”判断 |
| Workbench 文案 | `test/workbench_about_dialog_test.dart`、`test/workbench_bottom_bar_test.dart`、`test/widget_test.dart` | 关于弹窗、空态、导入失败、主动作不再只写“视频”；没有误导性的音频编辑 / 波形文案 | 首个切片已更新 about 和主要结果文案 |
| 完成弹窗 | 新增或扩展 `test/task_completed_dialog_test.dart` | 标题使用“处理完成”或按 purpose 展示；指标为“源文件 / 输出文件”；打开输出位置行为不变 | 首个切片已替换“压缩前 / 压缩后”唯一文案 |
| 弹窗风格回归 | `test/workbench_dialog_style_test.dart` | 新增媒体配置、完成、导入失败等弹窗不使用默认 `AlertDialog`，保持统一工作台弹窗框架 | 防止 UI 风格回退 |

## 3. 手动功能测试项

| 场景 | 操作 | 期望结果 |
| --- | --- | --- |
| 旧视频任务恢复 | 使用已有本地数据库启动应用 | 旧任务可加载；旧视频配置能显示为新 `MediaTaskConfig.video`；状态、源文件缺失标记和输出路径不丢失 |
| 视频导入回归 | 点击添加，选择 `.mp4`、`.mov`、`.mkv` 视频 | 任务进入分析中，分析成功后进入待处理；配置弹窗显示视频面板 |
| 视频处理回归 | 对普通视频执行压缩、转封装、目标体积两遍压缩 | 输出文件生成；进度连续更新；完成弹窗可打开输出位置；日志可查看 |
| 高风险视频回归 | 导入 iPhone HDR / HVC1 / 10-bit MOV，选择自动编码 | 自动策略仍能安全降级；主音频流选择不带入不可转码 APAC / `none` 流 |
| 图片导入 | 点击添加或拖拽 `.jpg`、`.png`、`.webp` | 不再提示只支持视频；任务可分析；列表显示图片类型和缩略图 |
| 图片配置 | 打开图片任务配置，修改格式、分辨率预设、质量和元数据保留开关 | 保存后任务显示已修改；执行命令使用对应图片参数 |
| 图片处理 | 执行 JPEG、PNG、WebP 输出各一例 | 输出文件存在；图片任务使用步骤型进度，不因缺少 duration 卡住 |
| 大图处理 | 导入大尺寸图片并选择长边限制 | 输出尺寸符合配置，宽高比保持，应用不明显卡死 |
| 音频导入 | 点击添加或拖拽 `.mp3`、`.m4a`、`.aac`、`.wav`、`.flac` | 任务可分析；列表显示音频类型和占位缩略图；不出现视频流缺失错误 |
| 音频配置 | 打开音频任务配置，修改格式、码率、采样率、声道 | 保存后任务显示已修改；执行命令包含音频参数 |
| 音频处理 | 执行 MP3、M4A/AAC、FLAC 输出各一例 | 输出音频文件可播放；命令禁用视频流；完成弹窗显示源文件 / 输出文件 |
| 不支持文件 | 导入 `.txt`、损坏媒体文件或未知扩展名 | 应用给出明确失败原因，不创建不可执行任务 |
| 文件夹导入 | 拖拽文件夹到窗口 | 显示只能导入媒体文件、不能导入文件夹；应用不中断 |
| 重新指定源文件 | 移动源文件后启动应用，再为视频 / 图片 / 音频分别重新指定同类型文件 | 同类型替换成功并重新分析；任务配置保留 |
| 跨类型替换 | 尝试用音频替换视频任务、用视频替换图片任务 | 拒绝替换并提示媒体类型不一致 |
| 输出路径冲突 | 对同名输出文件重复执行视频 / 图片 / 音频任务 | 自动追加后缀，不覆盖已有文件 |
| 完成弹窗 | 分别完成视频、图片、音频任务 | 标题和指标为通用处理结果；输出路径可横向滚动；打开文件位置可用 |
| 任务控制 | 对三类任务分别执行开始、暂停、继续、取消、重试、删除、清空 | 状态流稳定；取消会停止执行；失败任务保留错误信息并可重试 |
| 顶部通知和右键菜单 | 触发导入失败、分析失败、执行失败，并右键任务查看日志 / 打开位置 / 重命名 | 通知不遮挡关键按钮；右键菜单行为不因媒体类型变化失效 |

## 4. 平台 / 构建 / 打包验证

| 平台或产物 | 验证方式 | 期望结果 |
| --- | --- | --- |
| Dart 代码生成 | `dart run build_runner build --delete-conflicting-outputs` | Drift schema 14 相关生成文件更新成功，`app_database.g.dart` 不手写 |
| Dart 格式 | `git ls-files '*.dart' \| xargs dart format --set-exit-if-changed` | 所有 Dart 文件格式符合项目规则 |
| macOS 开发运行 | `flutter run -d macos` | 应用启动；视频 / 图片 / 音频导入、分析、处理和打开输出位置可手动验证 |
| Windows 开发运行 | `flutter run -d windows` | 应用启动；添加文件路径可用；管理员模式拖拽提示不回退 |
| macOS Release app | `flutter build macos --release` | Release app 构建成功；内置 FFmpeg / FFprobe 可被运行时定位 |
| macOS DMG | `scripts/build_dmg_macos.sh` | 生成 `build/macos/Build/Products/Release/FrameLean-v1.1.5.dmg`；DMG 内 app 可启动并处理三类媒体 |
| Windows Release zip | `PowerShell -ExecutionPolicy Bypass -File scripts\build_windows.ps1` | 生成 `build/windows/x64/runner/FrameLean-v1.1.5-windows-x64.zip`；Release 目录包含 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe` |
| 内置 FFmpeg 验证 | macOS 执行包内 `ffmpeg -hide_banner -encoders`、`ffprobe -hide_banner -version`；Windows 执行 Release `ffmpeg.exe` / `ffprobe.exe` | FFmpeg / FFprobe 可运行，包含视频、图片、音频处理所需 encoder / muxer |
| FFmpeg 日志路径 | 完成一次三类媒体任务后检查临时日志 | 日志记录真实 `ffmpegPath`、命令参数、stderr 尾部；失败摘要不写入 SQLite 日志正文 |
| Windows Explorer 定位 | Windows 输出路径包含空格或中文时点击“打开文件存放位置” | Explorer 打开并定位输出文件，视频 / 图片 / 音频都可用 |

## 5. API / 服务端测试项

| 接口或链路 | 请求/步骤 | 期望结果 | 文档产物 |
| --- | --- | --- | --- |
| 不适用 | 本功能是本地 Flutter 桌面媒体处理能力，不引入 HTTP API、后端服务或云端处理 | 不创建 API 测试脚本；不把服务端检查强行加入本地功能验收 | 无 |

## 6. 不覆盖范围

- 文件夹递归批量导入。
- GIF 动图专门优化。
- 图片 EXIF 编辑、水印、批量元数据处理。
- 音频裁剪、淡入淡出、音量标准化、波形预览、试听对比。
- 多音轨选择、字幕处理和复杂视频编辑。
- 后端服务、云端处理、账户体系、授权或 API 链路。
- 立即删除旧 `video_*` 数据库列后的长期清理验证。
- Linux / Web 发布级验证。

## 7. 验收标准

- `flutter analyze` 通过。
- `flutter test` 通过。
- Drift schema 14 生成文件由 `build_runner` 生成，旧 schema 13 数据可迁移，旧视频任务可读取。
- `MediaTask.config` 主类型不再是 `VideoTaskConfig`，但旧视频配置可兼容映射到 `MediaTaskConfig.video`。
- 视频命令构造、FFprobe 分析、队列执行、进度、缩略图和完成弹窗行为不回退。
- 图片任务可以导入、分析、配置、执行并生成输出文件；缺少 duration 时不阻塞进度。
- 音频任务可以导入、分析、配置、执行并生成输出文件；输出命令禁用视频流。
- 工作台文件选择、拖拽、空态、导入失败、关于弹窗、配置弹窗、任务列表和完成弹窗使用通用媒体文案。
- macOS 和 Windows 至少各完成一次视频、图片、音频的手动端到端处理验证。
- 实现后同步 `docs/README.md`、`docs/develop/architecture.md`、`docs/develop/data-model.md`、`docs/develop/test-plan.md`、`docs/develop/technology-stack.md` 和 `docs/product/roadmap.md`。
