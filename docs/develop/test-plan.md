# 测试计划

## 测试目标

这份计划记录 FrameLean 当前项目需要验证的范围。它面向当前代码，不绑定旧版本号。

测试目标：

- 保证 Flutter / Dart 代码通过静态分析。
- 保证核心业务服务的单元测试通过。
- 保证 FFmpeg / FFprobe 相关命令构造、进度解析和异常处理可控。
- 保证 macOS 和 Windows 构建前后关键路径可手动验证。

## 必跑命令

提交或构建前必须运行：

```bash
flutter analyze
flutter test
```

只验证单个模块时，可以运行指定测试文件：

```bash
flutter test test/ffmpeg_command_builder_test.dart
```

## 当前测试文件

```text
test/
  app_cache_cleaner_test.dart
  app_notification_host_test.dart
  app_notification_manager_test.dart
  app_settings_page_test.dart
  app_settings_save_coordinator_test.dart
  app_settings_test.dart
  app_settings_use_cases_test.dart
  architecture_dependencies_test.dart
  bundled_proprietary_audio_adapter_registry_test.dart
  compression_advisor_test.dart
  compression_estimator_test.dart
  compression_mode_mapper_test.dart
  drift_app_settings_repository_test.dart
  drift_app_notification_repository_test.dart
  drift_media_task_repository_test.dart
  ffmpeg_command_builder_test.dart
  ffmpeg_encoder_capabilities_test.dart
  ffmpeg_process_observer_test.dart
  ffmpeg_task_queue_runner_test.dart
  ffprobe_media_analyzer_test.dart
  file_extension_media_kind_resolver_test.dart
  framelean_responsive_test.dart
  generate_preview_frames_use_case_test.dart
  media_input_preparer_test.dart
  media_output_format_test.dart
  media_task_execution_use_cases_test.dart
  media_task_notifier_test.dart
  media_task_use_case_helpers_test.dart
  media_task_policy_tags_test.dart
  native_ncm_audio_decoder_test.dart
  notification_center_panel_test.dart
  output_preflight_service_test.dart
  preview_frame_generator_test.dart
  proprietary_audio_decoder_dispatcher_test.dart
  proprietary_audio_format_resolver_test.dart
  reorder_media_tasks_use_case_test.dart
  standard_cli_proprietary_audio_decoder_test.dart
  task_completion_sound_player_test.dart
  theme_prefs_reconciler_test.dart
  video_thumbnail_generator_test.dart
  widget_test.dart
  workbench_bottom_bar_test.dart
  workbench_constants_test.dart
  workbench_dialog_style_test.dart
  workbench_external_link_opener_test.dart
  workbench_file_revealer_test.dart
  workbench_notice_test.dart
  workbench_preview_notifier_test.dart
```

## 自动化测试覆盖范围

### 应用设置

- 应用设置初始默认值、复制更新和可空路径清除。
- 应用设置读取和保存 Use Cases。
- Drift `settings` 行和领域模型之间的映射。
- `theme_mode` 可保存 / 读取；未知主题值回退跟随系统。
- `theme_prefs.json` 作为首帧缓存镜像，读写失败或损坏时不影响启动；启动后 DB 与缓存不一致时以 `settings.theme_mode` 为准对齐应用状态并重写缓存。
- 应用设置页面的侧边栏导航、三类默认媒体配置、缓存清理入口和保存返回行为。
- “关闭通知角标”默认开启，可按应用设置分区独立保存、取消和持久化读取。
- 完成弹窗设置不再出现在应用设置页；旧数据库列只作为兼容列保留，不映射到可修改的 domain / UI 设置。
- 任务完成提示音默认使用“清脆完成”，可在应用设置分区选择、保存、取消和持久化读取；本地播放通过 `audioplayers` 播放 Flutter asset，不启动 PowerShell。
- 底部栏设置入口和新任务默认配置应用。

### Application Use Cases

- 导入任务时套用应用默认设置、识别视频 / 图片 / 音频媒体类型并写入分析中状态。
- 输出设置保存后只批量刷新等待中、失败和已取消任务，运行中、已暂停和已完成任务保留当前执行快照。
- 启动恢复时校正源文件丢失、指纹变化和缺失分析结果。
- 重新指定源文件、失败重试、删除、清空、顶层任务 / 任务夹混排排序和夹内排序。
- 顶层任务 / 任务夹重排只持久化未入夹任务 `sort_order` 和任务夹 `sort_order`；夹内重排只持久化 `folder_sort_order`；运行中的顶层项或夹内任务作为排序边界。
- 任务夹创建、按媒体类型批量建夹、移入、移出和删除释放任务；批量导入按媒体类型自动建夹。
- 任务夹默认配置保存后只批量应用到非 `running` / `paused` / `analyzing` 任务；已完成、失败、已取消、等待中和缺失源任务保留状态但更新配置。
- 任务夹批量重试只影响 `completed` / `failed` / `cancelled` 终态任务，并保留任务当前配置。
- 任务夹启动下一项按 `folderSortOrder` 选择最靠前的可执行任务；夹内启动复用单任务插队执行语义。
- 队列启动、单任务开始 / 继续、暂停和清空时取消执行；清空会同步清空任务和任务夹。
- 预览帧生成通过 `GeneratePreviewFramesUseCase` 读取运行时并调用预览服务。
- 应用通知先持久化再展示；设置保存离开页面后仍记录结果；FFmpeg 队列完成 / 失败直接产生类型化任务通知；交互型通知只展示临时浮层、不进入通知中心。

### 架构依赖护栏

- `domain` 只能依赖领域层与 Dart 基础库，不得依赖 Flutter、Drift 或 `dart:io`。
- `application` 不得反向依赖 `app`、`features` 或 `infrastructure`，平台行为通过 application port 表达。
- `infrastructure` 不得导入 `features`，Riverpod 依赖装配统一放在 `app/providers`。
- `features` 不得直接依赖 `infrastructure`，跨功能共享展示组件统一放在 `app`。

### 通知中心

- 通知仓储按创建时间倒序读取全部未归档通知，并支持批量已读和批量软归档。
- 工作台通知按钮展示持久化未读数量角标。
- 工作台在“关闭通知角标”开启时隐藏角标，但不清除未读数量或禁用通知中心入口。
- 通知中心使用自制右侧浮层和滑入动画，不依赖 `Drawer` 或手势抽屉。
- 打开通知中心批量标记已读；浮层打开期间新增通知自动已读；清扫后列表和角标同步清空。
- 任务成功通知按类型化载荷显示“打开输出文件位置”文字按钮，正文包含文件名、源 / 输出体积、压缩比例、保存路径和耗时；任务失败通知显示文件名、原因和建议且不提供成果物动作。
- 版本更新通知按 `dedupe_key` 保证一个版本只展示一条；当前更新通知提供“查看版本日志”和“下载更新”文字按钮，历史更新通知提供日志查看动作。
- 点击任务完成临时通知会打开通知中心，并让对应通知项轻微高亮闪烁；临时通知的成果物文件夹图标可直接定位输出位置。
- 根级临时通知在已有通知展示时收到新通知，会先播放当前通知退出动画，再展示最新通知；快速连续通知只展示最后一条。
- 设置保存通知使用分区级真实事件文案；媒体任务通知标题直接表达“任务成功 / 任务失败”，完整指标和失败建议保留在通知中心正文，临时通知只承载短摘要。
- 任务成功通知会按应用设置播放内置完成提示音；通知中心打开时即使临时通知隐藏，也不影响完成音效触发。
- 通知中心通知项按标题、创建时间、正文和底部 `FilledButton` 文字按钮组分层展示，临时通知只承载短摘要且布局不跟随通知中心按钮组调整。
- 浮层支持点击遮罩和 `Esc` 关闭；打开期间不会与根级临时通知叠加。

### 持久化兼容

- `CompressionModeMapper` 将历史 `smart`、`quality` 读取为当前 `preset`。
- 当前 `CompressionMode.preset`、`CompressionMode.targetSize` 写入稳定持久化值。
- 任务配置优先通过 `media_config_json` 读写 `MediaTaskConfig`，旧视频列继续作为 fallback 和兼容写入。
- 视频 / 图片 / 音频任务的保持源格式配置只保存真实 `MediaOutputFormat` 和 `keepOriginalOutputFormat` 布尔状态，不写入 `source` 伪格式；不支持的源扩展名会回退到固定默认格式。
- 图片分析字段和旧视频 / 音频分析字段都能在 Drift 行和 domain 之间映射。
- `task_folders` 表、任务 `folder_id` / `folder_sort_order` 和 `policy_tags_json` 能在 Drift 行和 domain 之间映射。

### 压缩策略和体积预估

- 推荐方案预设的目标码率、音频码率和提示信息。
- 目标体积模式根据目标大小和时长计算码率。
- 极低码率或重复压缩场景的安全边界。
- 压缩结果预估在不同预设、编码和分辨率下的输出范围。

### 编码器能力

- FFmpeg 编码器列表解析。
- macOS VideoToolbox、Windows NVENC / Quick Sync / AMF 和软件编码后端的可用性判断。
- 自动编码器后端选择优先级。
- 编码格式和编码器后端不兼容时的异常处理。

### FFmpeg 命令构造

- 普通压缩命令。
- 目标体积 / 目标码率压缩命令。
- 智能预设和 CRF 参数。
- 输出格式、视频编码、分辨率预设。
- 输出目录、输出文件名、`{version}` 模板变量、`v1` 已存在时优先递增到 `v2` / `v3` 的路径冲突规则，以及无版本 token 时的中文括号后缀。
- 预览片段命令和预览帧命令。
- 硬件编码和软件编码参数差异。
- SDR 源色彩元数据按 FFprobe 结果保留；未知 SDR 才按分辨率推断，不再统一硬贴 BT.709。
- HDR10 / HLG 源默认使用 `zscale + tonemap` 转为 SDR BT.709；用户开启“保持 HDR”时，编码固定为 HEVC，使用 10-bit Main10 输出并保留基础 BT.2020 / PQ / HLG 色彩标记；保持 HDR 的滤镜链不得把 `bt2020nc` 写入 `scale` 的 `out_color_matrix`。
- Dolby Vision Profile 5 或缺少 HDR10 兼容层的 Dolby Vision 在命令构造阶段拒绝，避免输出变黑、偏紫或严重偏色。
- Dolby Vision 动态元数据不在当前保持 HDR 范围内；带 HDR10 兼容层的 Dolby Vision 只按 HDR10 基础层处理。
- 透明视频命中 alpha 像素格式后输出 MOV + ProRes 4444，命令中包含 `prores_ks` 和 `yuva444p10le`，不得退回 `yuv420p` / H.264。
- NVENC CQ、QSV global quality、AMF QP 和 VideoToolbox `q:v` 使用独立质量映射，不直接复用 CRF 数值。
- iPhone MOV 中只映射 FFprobe 选出的可转码主音频流，避免 `-map 0:a?` 把 APAC / `none` 音频流带入转码。
- 自动编码后端在高风险 Apple HDR / HVC1 / 10-bit MOV 上优先降级到可用的软件编码，显式选择硬件编码时保持用户选择。
- 图片任务可生成 JPEG / PNG / WebP 输出命令，支持质量、分辨率缩放、元数据保留策略和步骤型进度。
- 图片压缩命令优先按源格式生成首轮候选；首轮候选无效时根据 alpha 和 `libwebp` 能力选择 WebP / JPG fallback，透明图不得降级 JPG。
- 音频任务可生成 MP3、M4A/AAC、WAV、FLAC、AIFF、WMA、Opus 和 Ogg Opus 输出命令，使用 `-vn` 禁用视频流，并写入编码、码率、采样率和声道参数。

### 队列执行

- 有待处理任务时刷新队列状态。
- 启动单个任务和启动整个队列。
- 暂停、继续、取消和取消全部执行。
- 任务切换和串行执行。
- 底部暂停会暂停所有正在执行的任务并停止自动续跑；底部开始按实时列表顺序选择等待中 / 已暂停任务。
- 任务执行期间调整任务列表顺序后，当前任务完成时按最新列表顺序选择下一条可执行任务。
- 任务行开始按钮作为插队入口，先暂停当前前台任务并执行用户点击的任务，但不修改列表排序。
- FFmpeg 不可用时的失败状态。
- 极限压缩确认拦截。
- 输出 preflight 在 FFmpeg 启动前创建输出目录、检查同源覆盖 / 重名 / 可写性，并让最终启动参数使用改写后的输出路径。
- 图片首轮输出小于源文件时提前完成；首轮输出不小于源文件时删除候选并进入 fallback；fallback 仍不小于源文件或无法验证体积时失败、清空输出路径、保留失败原因并展示 `未有效压缩` 标签。
- 执行完成或失败后写回仓储。
- 进程启动失败、执行失败、取消和完成时都会向临时文件日志写入诊断尾部；日志不写入 SQLite。

### 进度观测

- 解析 FFmpeg `out_time_ms` 进度字段。
- 根据视频或音频时长计算任务进度。
- 图片等无时长任务使用步骤型进度，不依赖 duration。
- 时长缺失时保持安全状态。
- 退出码失败和输出文件缺失时标记失败。
- FFmpeg stderr 全量写入临时日志文件，失败消息只截取尾部作为任务错误摘要。

### 媒体分析

- FFprobe 分析时长、编码、码率、分辨率、音频和容器信息。
- 源文件不存在、FFprobe 不可用或分析失败时保存错误信息。
- 分析结果写回任务并刷新状态。
- FFprobe 保存可转码主音频流索引，并忽略 APAC / `none` 这类不能参与常规转码的音频流。
- FFprobe 保存 chroma location、HDR10 Mastering Display、MaxCLL / MaxFALL、Dolby Vision Profile 和兼容 ID。
- FFprobe 命中透明视频像素格式后任务展示 `透明保留` 策略标签。
- 纯音频没有视频流时仍可分析音频编码、码率、声道、采样率和时长。
- 静态图片没有 duration 时仍可分析图片宽高、编码、像素格式和位深。

### 预览和缩略图

- 预览帧生成的输入校验。
- 缺少时长、FFmpeg 不可用或命令失败时的错误处理。
- 参数变化后预览结果失效。
- 视频缩略图生成和失败缓存。
- 图片任务使用源图片作为缩略图；音频任务不触发视频缩略图抽帧。

### 工作台交互和风格

- 任务配置弹窗中“已修改”和“已压缩”只在底部按钮同排左侧显示。
- 未实际改变配置时不显示“已修改”。
- 任务列表通过拖拽手柄触发重排时不抛布局异常，且 reorder 回调被触发。
- 拖拽列表项内不启用 `Tooltip` overlay，使用 `Semantics` 保留无障碍标签。
- 运行中任务和包含运行中任务的任务夹拖拽手柄禁用；其他顶层项在队列执行期间仍可调整顺序以影响后续执行。
- 任务列表预热为 `AsyncData` 时，选中任务、配置和质量预设的初始同步仍会执行。
- 工作台总列表混排显示任务夹和未入夹任务，夹内任务不在总列表重复出现；任务和任务夹可以通过拖拽手柄互相切换顺序；点击任务夹主体打开“任务夹设置”，点击尾部查看按钮打开左侧内容浮层。
- 任务夹内容浮层复用普通任务行样式，夹内任务可以启动、暂停、重试、重链、查看日志、排序和移出，且任务主体点击不会打开配置弹窗。
- 全应用 `FrameLeanReorderableListView` 独立验证原生 reorder 索引语义、拖拽更新、`move / hold / restoreOrigin` gap 策略、跨轴外部 drop、取消 drop 和外部接收时同步移除源 item 的安全性。
- 夹内任务拖到遮罩时 gap 恢复原位、遮罩高亮，释放后只触发移出并原地缩小淡出；标题区或面板内空白区释放取消，不移出也不排序。
- 夹内排序在异步持久化完成前保持目标顺序；移出失败恢复任务行，运行中任务拖拽柄禁用。
- 移出任务的新 `sortOrder` 大于所有顶层普通任务和任务夹；普通模式与多选模式任务行均不显示选中边框。
- 多选模式显示复选框，选中未入夹任务后显示创建任务夹 FAB，并按媒体类型拆分创建任务夹。
- 普通模式下未入夹任务的拖拽柄同时承担排序和入夹：经过同类型任务夹整行时任务夹原地停留且不触发排序 gap 位移动画，从普通任务返回任务夹时已有 gap 会复位；释放在中部主体会入夹，释放在上下 16px 边缘仍排序，离开任务夹行到普通任务上才恢复排序预览；排序释放后在异步持久化完成前仍保持目标视觉顺序，不回闪到旧槽位。不同媒体类型任务夹在拖起时禁用显示并作为排序目标处理。普通模式也支持框选，命中任务后进入多选；Command / Control 框选按反选处理。
- 任务行右侧开始 / 暂停 / 重试 / 移除按钮不会触发任务行配置弹窗。
- 顶部栏主题按钮可在浅色和深色之间切换。
- 深色主题下分段滑杆 thumb 使用主色，不和深色 surface 混在一起。
- 默认 `AlertDialog` 不应出现在统一样式弹窗中。
- 工作台预览状态入口能正确记录生成中、错误、对比比例和选中帧。

### Widget 基础验证

- 应用可以构建基础 Widget 树。
- 主入口和路由不会在基础测试中崩溃。

## 手动验证范围

### 基础启动

- macOS 开发运行：`flutter run -d macos`。
- Windows 开发运行：`flutter run -d windows`。
- 首次启动能进入工作台页面。
- Windows 首次启动窗口默认显示在主屏幕工作区中间。
- Windows 4K / 大窗口环境下，工作台和设置页文字按桌面缩放策略在上限内放大，不再被固定压回基础字号。
- Windows 管理员模式启动时显示拖拽限制提示，点击“普通模式重启”后新窗口以普通权限启动。
- 已有任务能从本地数据库恢复。

### 文件导入

- 点击底部 `+` 选择单个视频。
- 点击底部 `+` 选择多个视频。
- 点击底部 `+` 选择图片或音频。
- 拖拽单个视频到窗口。
- 拖拽多个视频到窗口。
- 拖拽图片或音频到窗口。
- Windows 管理员模式运行时，应用提示拖拽可能受系统权限隔离影响，并保留点击 `+` 添加文件作为可用路径。
- 拖拽文件夹时显示失败原因。
- 导入不支持的文件扩展名时显示只能导入媒体文件的提示。
- 大写 `.MOV` 后缀视频可以导入并开始压缩；如果输出文件名只和源文件大小写不同，应自动追加中文括号后缀。
- 大写图片和音频扩展名可以识别为对应媒体类型。
- 批量导入多个同类型文件时自动创建一个任务夹；混合导入时按视频 / 图片 / 音频分别创建任务夹；单文件导入不创建任务夹。

### 媒体分析和任务列表

- 新任务进入“分析中”。
- 分析成功后显示源文件信息。
- 分析失败后显示错误状态和顶部通知。
- 源文件被移动或删除后任务变成“找不到源文件”。
- 任务列表缩略图正常显示或失败后不反复生成。

### 任务配置

- 点击任务卡片打开“任务详情设置”弹窗。
- 切换清晰优先、均衡推荐、微信发送、体积优先。
- 切换自定义目标体积模式，并通过 10% 到 90% 的比例滑杆选择目标体积；滑杆标题同排右侧显示压缩体积百分比。
- 修改输出格式、视频编码和分辨率。
- 启用“保持源文件格式”后，格式下拉显示真实源格式加“保持原始”后缀，例如 `MP4（保持原始）`、`PNG（保持原始）`；底层配置仍写入真实格式枚举。
- 如果真实源格式已经作为 `保持原始` 选项出现，下拉列表不再重复显示同一个普通格式选项；源分辨率也同理。
- HDR 源视频显示“保持 HDR”开关；开启后视频编码切换到 HEVC 并禁用编码选择，自动回到推荐方案并默认清晰优先，“自定义目标体积”“微信发送”和“体积优先”不可选；关闭后恢复开启前的编码选择。
- 保存配置后任务使用新配置。
- 没有实质修改配置时，不应显示“已修改”。
- “已修改”和“已压缩”显示在弹窗底部按钮同排左侧，不显示在推荐方案或目标体积区域内。
- 图片任务通过 10% 到 100% 的分段质量滑杆修改质量；滑杆标题同排右侧显示保留质量百分比。
- 图片、视频和音频任务配置面板可修改分类型处理配置；非视频任务打开任务详情时不得读取视频专属编码器状态。
- 图片、视频和音频任务都可配置元数据保留策略，三类媒体默认均保留元数据。

### 任务夹交互

- 任务夹作为总列表项显示，夹内任务不在总列表重复出现。
- 点击任务夹主体打开夹级配置，保存后应用到夹内可安全更新的任务。
- 点击任务夹尾部查看按钮打开左侧内容浮层；浮层显示夹名、任务数和夹内任务列表。
- 点击夹内任务尾部“移出”后，该任务从浮层消失并回到总列表；夹内任务尾部启动 / 暂停 / 重试 / 重链 / 日志按钮可独立触发，不打开配置弹窗；夹内任务显示独立进度条和拖拽手柄。
- 任务夹尾部主按钮在有运行任务时暂停夹内运行任务，否则启动夹内下一项可执行任务；没有可执行任务但有终态任务时批量重试终态任务。
- 主列表多选 FAB 可以按媒体类型创建任务夹；未入夹任务经过同类型任务夹整行时不换位，释放中部主体时入夹，释放上下 16px 边缘时排序，离开任务夹行后才恢复排序预览；跨类型任务夹在拖起时禁用显示并作为排序目标处理。
- 任务夹尾部不显示重链按钮，副标题在任务数、完成数和失败数后追加源文件丢失计数。
- 删除任务夹只释放夹内任务，不删除任务记录或源文件；任务夹没有任务时自动删除，当前打开的空夹同步关闭左侧浮层。

### 队列和任务控制

- 点击单个任务的开始按钮能执行该任务。
- 点击底部主按钮能启动队列。
- 底部主按钮按总列表顺序执行，遇到任务夹时按夹内顺序展开执行；执行中点击某个任务开始会插队，插队完成后继续按最新展开顺序执行。
- 运行中任务显示进度。
- 运行中任务可以暂停。
- 暂停任务可以继续。
- 任务可以取消、删除和重试。
- 已完成任务显示“重来”，点击后从源文件检查和媒体分析重新开始。
- 清空列表前出现确认弹窗。
- 清空列表会取消执行并移除所有任务和任务夹。
- 图片压缩输出如果第一轮不小于源文件，应自动尝试 WebP / JPG fallback；第二轮仍不小于源文件时任务失败，提示“图片未有效压缩”或无法验证体积的具体原因，并清理无效输出。
- 透明视频导入分析后应展示 `透明保留` 标签，执行时输出 MOV / ProRes 4444；如果 FFmpeg 不支持 `prores_ks`，任务应在命令构造阶段失败并提示更换 FFmpeg 或素材。

### 通知和弹窗风格

- 顶部通知从右向左进入，并在关闭时播放退出动画。
- 通知边距、颜色、圆角和阴影与工作台视觉风格一致。
- 临时通知保持中等密度，关闭按钮固定在通知框尾部，详情文本最多展示两行。
- Windows 顶部保留通知安全区，通知不遮挡单任务列表项右侧按钮。
- 点击右上角通知按钮后，通知中心从窗口右侧向左滑入；再次点击、点击遮罩或按 `Esc` 可关闭。
- 通知中心展示全部未归档通知，打开后角标归零；清扫按钮清空当前通知列表。
- 应用设置默认隐藏通知角标；关闭“关闭通知角标”后，工作台按未读数量重新显示角标。
- 任务成功 / 失败通知标题直接表达结果；通知中心正文展示完整指标或失败建议，按钮组位于正文下方；任务成功按钮能在 Finder / Explorer 中定位成果物。
- 在设置页选择非“不开启”完成提示音后，任务处理完成时播放一次短提示音；Windows 播放时不启动 `powershell.exe`。
- 压缩确认、导入失败、清空任务和重命名弹窗使用统一工作台弹窗框架。
- 关于内容只在设置页面展示，工作台不再提供关于弹窗入口。
- 关于栏更新按钮在 `检查更新`、`检查中`、`现在更新`、下载百分比、暂停 / 继续和 `重启更新` 状态间切换时保持固定尺寸。
- 工作台顶部在存在更新、下载中、暂停或待重启时显示持续更新入口；下载中显示圆形进度，点击打开版本日志弹窗。
- 下载完成待重启时，如果存在运行中、暂停中、等待中或分析中任务，先显示项目风格警告弹窗，确认后暂停任务并启动 updater helper。

### 完成和结果处理

- 处理完成后不弹出完成提示弹窗，完成反馈只通过完成提示音、临时通知、通知中心和任务项尾部文件入口表达。
- 已完成且存在 `outputPath` 的任务项尾部显示完成文件入口，点击后打开 Finder、Explorer 或文件管理器并定位输出文件。
- Windows 输出路径包含空格或中文时，点击“打开完成文件位置”可以打开 Explorer 并定位到目标文件。
- 任务成功通知中心正文显示文件名、源文件体积、输出文件体积、压缩比例、保存路径和耗时。
- 图片输出不小于源文件等失败通知应明确失败原因，并建议切换 WebP / JPG、降低质量或更换输出格式。
- 失败任务保留错误信息并可重试。

### 右键菜单

- 右键任务可以打开文件所在位置。
- 右键任务可以重命名。
- 右键任务可以查看 FFmpeg 执行日志。
- 重命名为空时显示提示。
- 右键任务可以删除。

### macOS 构建验证

- GitHub Actions `build-macos.yml` 安装 `autoconf`、`automake`、`libtool`、`nasm` 和 `pkg-config`。
- GitHub Actions `build-macos.yml` 显式启用 Flutter Swift Package Manager；`macos/` 工程不应包含 `Podfile`、`Podfile.lock`、`Pods.xcodeproj`、`Pods-Runner` 或 `[CP]` Build Phase。
- `scripts/release/build_dmg_macos.sh` 使用 UTF-8 locale，并在 `flutter build macos --release` 前后检查 CocoaPods 残留，避免 release runner 继续触发 `pod install`。
- macOS 运行时 slice 通过 tar.gz 上传 / 下载，避免 GitHub Actions artifact zip 丢失可执行权限；Universal 合并脚本能在必要时修复可执行位，并找到真实架构 slice 下的 `ffmpeg`、`ffprobe` 和 QMC 适配器。
- `flutter build macos --release` 成功。
- `FrameLean.app` 中存在内置 FFmpeg / FFprobe。
- `scripts/release/verify_macos_universal.sh FrameLean.app` 成功，包内 Mach-O 文件均包含 `x86_64` 和 `arm64`。
- 生成 `build/macos/Build/Products/Release/FrameLean-v1.2.1.dmg`。
- 运行 Release app 后任务使用 app 包内 FFmpeg。
- 在 Apple Silicon Mac 和 Intel Mac 上使用同一 DMG 验证启动、导入、压缩和打开输出位置。
- 两种架构分别验证 VideoToolbox 探测与软件编码回退。

### Windows 构建验证

- `PowerShell -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1` 成功。
- Release 目录存在 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe`。
- 发布脚本完整收集 `ffmpeg.exe -version` 和 `ffprobe.exe -version` 输出后检查 exit code，不通过提前截断管道判断原生命令状态。
- Release 目录存在 `msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`。
- Release 目录存在 `audio_adapters/qmc/qmc-decrypt.exe`，并包含上游许可证。
- 生成 `build/windows/x64/runner/FrameLean-v1.2.1-windows-x64.zip`。
- 生成 `build/windows/x64/installer/FrameLean-v1.2.1-windows-x64-setup.exe`。
- zip 解压后顶层目录为 `FrameLean-v1.2.1-windows-x64/`。
- 在未预装 Visual C++ Redistributable 的干净 Windows x64 环境中，安装后可以启动应用。
- 安装器默认安装到 `%LOCALAPPDATA%\Programs\FrameLean`，不请求管理员权限，开始菜单快捷方式可以启动应用。
- 安装器提供可选桌面快捷方式任务；默认不强制创建，用户勾选后桌面出现 FrameLean 快捷方式。
- 使用 `/SILENT /SUPPRESSMSGBOXES /NORESTART` 覆盖安装时不触发 UAC，并返回可判断的安装器退出码。
- 同一 `AppId` 的新版本可以覆盖升级，升级后应用和内置运行时正常。
- 自托管更新 helper 随包提供 `FrameLeanUpdaterHelper.exe`，主应用下载并校验安装器后启动 helper 并退出；helper 负责等待主程序退出、运行安装器、检查安装器退出码并重启应用。
- 从 Windows“已安装的应用”卸载后，应用目录、注册表安装信息和用户数据按当前彻底卸载策略清理。
- Windows app 可以启动、导入、压缩和打开输出位置。
- MGG / MFLAC 输入能够调用安装包内的 `qmc-decrypt.exe`；需要 ekey 的变体显示可读错误。
- GPU 编码器不可用时可以回退到软件编码。
- GitHub Actions artifact 分别上传便携 ZIP 和 `setup.exe` 安装器；Tag Release 同时附加两个发布包。

## 内置 FFmpeg 验证

macOS：

```bash
APP="build/macos/Build/Products/Release/FrameLean.app"
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -encoders
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -filters
"$APP/Contents/Resources/ffmpeg/ffprobe" -hide_banner -version
```

Windows：

```powershell
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -encoders
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -filters
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe -hide_banner -version
```

运行任务后查看 macOS 日志中的 FFmpeg 路径：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)framelean/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```
