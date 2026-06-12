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
  app_settings_page_test.dart
  app_settings_test.dart
  app_settings_use_cases_test.dart
  app_notification_host_test.dart
  app_notification_manager_test.dart
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
  native_ncm_audio_decoder_test.dart
  notification_center_panel_test.dart
  preview_frame_generator_test.dart
  proprietary_audio_decoder_dispatcher_test.dart
  proprietary_audio_format_resolver_test.dart
  reorder_media_tasks_use_case_test.dart
  standard_cli_proprietary_audio_decoder_test.dart
  theme_prefs_reconciler_test.dart
  video_thumbnail_generator_test.dart
  widget_test.dart
  workbench_about_dialog_test.dart
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
- 底部栏设置入口和新任务默认配置应用。

### Application Use Cases

- 导入任务时套用应用默认设置、识别视频 / 图片 / 音频媒体类型并写入分析中状态。
- 启动恢复时校正源文件丢失、指纹变化和缺失分析结果。
- 重新指定源文件、失败重试、删除、清空和排序。
- 任务重排只持久化 `sort_order` 字段，失败时刷新仓储顺序，避免 UI 顺序和 DB 顺序分裂。
- 队列启动、单任务开始 / 继续、暂停和清空时取消执行。
- 预览帧生成通过 `GeneratePreviewFramesUseCase` 读取运行时并调用预览服务。
- 应用通知先持久化再展示；设置保存离开页面后仍记录结果；FFmpeg 队列完成 / 失败直接产生类型化任务通知。

### 通知中心

- 通知仓储按创建时间倒序读取全部未归档通知，并支持批量已读和批量软归档。
- 工作台通知按钮展示持久化未读数量角标。
- 工作台在“关闭通知角标”开启时隐藏角标，但不清除未读数量或禁用通知中心入口。
- 通知中心使用自制右侧浮层和滑入动画，不依赖 `Drawer` 或手势抽屉。
- 打开通知中心批量标记已读；浮层打开期间新增通知自动已读；清扫后列表和角标同步清空。
- 任务成功通知按类型化载荷显示成果物文件夹按钮；任务失败通知显示原因且不提供成果物动作。
- 通知项副标题保留结果信息，并显示通知创建时间。
- 浮层支持点击遮罩和 `Esc` 关闭；打开期间不会与根级临时通知叠加。

### 持久化兼容

- `CompressionModeMapper` 将历史 `smart`、`quality` 读取为当前 `preset`。
- 当前 `CompressionMode.preset`、`CompressionMode.targetSize` 写入稳定持久化值。
- 任务配置优先通过 `media_config_json` 读写 `MediaTaskConfig`，旧视频列继续作为 fallback 和兼容写入。
- 图片分析字段和旧视频 / 音频分析字段都能在 Drift 行和 domain 之间映射。

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
- 输出目录、输出文件名和路径冲突自动加后缀。
- 预览片段命令和预览帧命令。
- 硬件编码和软件编码参数差异。
- iPhone MOV 中只映射 FFprobe 选出的可转码主音频流，避免 `-map 0:a?` 把 APAC / `none` 音频流带入转码。
- 自动编码后端在高风险 Apple HDR / HVC1 / 10-bit MOV 上优先降级到可用的软件编码，显式选择硬件编码时保持用户选择。
- 图片任务可生成 JPEG / PNG / WebP 输出命令，支持质量、分辨率缩放、元数据保留策略和步骤型进度。
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
- 运行中任务的拖拽手柄禁用；其他任务在队列执行期间仍可调整顺序以影响后续执行。
- 任务列表预热为 `AsyncData` 时，选中任务、配置和质量预设的初始同步仍会执行。
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
- 大写 `.MOV` 后缀视频可以导入并开始压缩；如果输出文件名只和源文件大小写不同，应自动追加数字后缀。
- 大写图片和音频扩展名可以识别为对应媒体类型。

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
- 保存配置后任务使用新配置。
- 没有实质修改配置时，不应显示“已修改”。
- “已修改”和“已压缩”显示在弹窗底部按钮同排左侧，不显示在推荐方案或目标体积区域内。
- 图片任务通过 10% 到 100% 的分段质量滑杆修改质量；滑杆标题同排右侧显示保留质量百分比。
- 图片和音频任务配置面板可修改分类型处理配置。

### 队列和任务控制

- 点击单个任务的开始按钮能执行该任务。
- 点击底部主按钮能启动队列。
- 运行中任务显示进度。
- 运行中任务可以暂停。
- 暂停任务可以继续。
- 任务可以取消、删除和重试。
- 已完成任务显示“重来”，点击后从源文件检查和媒体分析重新开始。
- 清空列表前出现确认弹窗。
- 清空列表会取消执行并移除任务。

### 通知和弹窗风格

- 顶部通知从右向左进入，并在关闭时播放退出动画。
- 通知边距、颜色、圆角和阴影与工作台视觉风格一致。
- Windows 顶部保留通知安全区，通知不遮挡单任务列表项右侧按钮。
- 点击右上角通知按钮后，通知中心从窗口右侧向左滑入；再次点击、点击遮罩或按 `Esc` 可关闭。
- 通知中心展示全部未归档通知，打开后角标归零；清扫按钮清空当前通知列表。
- 应用设置默认隐藏通知角标；关闭“关闭通知角标”后，工作台按未读数量重新显示角标。
- 任务成功通知右上角显示文件夹按钮，并能在 Finder / Explorer 中定位成果物。
- 压缩确认、导入失败、清空任务和重命名弹窗使用统一工作台弹窗框架。
- 关于内容只在设置页面展示，工作台不再提供关于弹窗入口。

### 完成和结果处理

- 处理完成后弹出完成提示。
- 完成提示只保留取消和打开文件存放位置两个按钮。
- 完成提示显示源文件体积、输出文件体积和一行可复制导出路径。
- 导出路径过长时保持单行横向滚动，不撑大弹窗主体。
- 点击“打开文件存放位置”可以打开 Finder、Explorer 或文件管理器。
- Windows 输出路径包含空格或中文时，点击“打开文件所在位置”可以打开 Explorer 并定位到目标文件。
- 完成提示中的“重来”可以关闭弹窗并重新分析、重新执行该任务。
- 失败任务保留错误信息并可重试。

### 右键菜单

- 右键任务可以打开文件所在位置。
- 右键任务可以重命名。
- 右键任务可以查看 FFmpeg 执行日志。
- 重命名为空时显示提示。
- 右键任务可以删除。

### macOS 构建验证

- `flutter build macos --release` 成功。
- `FrameLean.app` 中存在内置 FFmpeg / FFprobe。
- 生成 `build/macos/Build/Products/Release/FrameLean-v1.1.5.dmg`。
- 运行 Release app 后任务使用 app 包内 FFmpeg。
- 在另一台 Apple Silicon Mac 上验证启动、导入、压缩和打开输出位置。

### Windows 构建验证

- `PowerShell -ExecutionPolicy Bypass -File scripts\release\build_windows.ps1` 成功。
- Release 目录存在 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe`。
- Release 目录存在 `msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`。
- Release 目录存在 `audio_adapters/qmc/qmc-decrypt.exe`，并包含上游许可证。
- 生成 `build/windows/x64/runner/FrameLean-v1.1.5-windows-x64.zip`。
- 生成 `build/windows/x64/installer/FrameLean-v1.1.5-windows-x64-setup.exe`。
- zip 解压后顶层目录为 `FrameLean-v1.1.5-windows-x64/`。
- 在未预装 Visual C++ Redistributable 的干净 Windows x64 环境中，安装后可以启动应用。
- 安装器默认安装到 `%LOCALAPPDATA%\Programs\FrameLean`，不请求管理员权限，开始菜单快捷方式可以启动应用。
- 使用 `/SILENT /SUPPRESSMSGBOXES /NORESTART` 覆盖安装时不触发 UAC，并返回可判断的安装器退出码。
- 同一 `AppId` 的新版本可以覆盖升级，升级后应用和内置运行时正常。
- 从 Windows“已安装的应用”卸载后，应用目录、注册表安装信息和用户数据按当前彻底卸载策略清理。
- Windows app 可以启动、导入、压缩和打开输出位置。
- MGG / MFLAC 输入能够调用安装包内的 `qmc-decrypt.exe`；需要 ekey 的变体显示可读错误。
- GPU 编码器不可用时可以回退到软件编码。
- GitHub Actions artifact 和 Tag Release 同时包含 ZIP 与 `setup.exe`。

## 内置 FFmpeg 验证

macOS：

```bash
APP="build/macos/Build/Products/Release/FrameLean.app"
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -encoders
"$APP/Contents/Resources/ffmpeg/ffprobe" -hide_banner -version
```

Windows：

```powershell
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -encoders
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe -hide_banner -version
```

运行任务后查看 macOS 日志中的 FFmpeg 路径：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)framelean/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```
