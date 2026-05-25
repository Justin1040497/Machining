# 测试计划

## 测试目标

这份计划记录 Machining 当前项目需要验证的范围。它面向当前代码，不绑定旧版本号。

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
  app_settings_dialog_test.dart
  app_settings_test.dart
  app_settings_use_cases_test.dart
  compression_advisor_test.dart
  compression_estimator_test.dart
  compression_mode_mapper_test.dart
  drift_app_settings_repository_test.dart
  ffmpeg_command_builder_test.dart
  ffmpeg_encoder_capabilities_test.dart
  ffmpeg_process_observer_test.dart
  ffmpeg_task_queue_runner_test.dart
  ffprobe_media_analyzer_test.dart
  generate_preview_frames_use_case_test.dart
  media_task_execution_use_cases_test.dart
  media_task_notifier_test.dart
  preview_frame_generator_test.dart
  video_thumbnail_generator_test.dart
  workbench_bottom_bar_test.dart
  workbench_dialog_style_test.dart
  workbench_preview_notifier_test.dart
  widget_test.dart
```

## 自动化测试覆盖范围

### 应用设置

- 应用设置初始默认值、复制更新和可空路径清除。
- 应用设置读取和保存 Use Cases。
- Drift `settings` 行和领域模型之间的映射。
- 应用设置弹窗的紧凑态、高级态和保存行为。
- 底部栏设置入口和新任务默认配置应用。

### Application Use Cases

- 导入任务时套用应用默认设置、识别媒体类型并写入分析中状态。
- 启动恢复时校正源文件丢失、指纹变化和缺失分析结果。
- 重新指定源文件、失败重试、删除、清空和排序。
- 队列启动、单任务开始 / 继续、暂停和清空时取消执行。
- 预览帧生成通过 `GeneratePreviewFramesUseCase` 读取运行时并调用预览服务。

### 持久化兼容

- `CompressionModeMapper` 将历史 `smart`、`quality` 读取为当前 `preset`。
- 当前 `CompressionMode.preset`、`CompressionMode.targetSize` 写入稳定持久化值。

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

### 队列执行

- 有待处理任务时刷新队列状态。
- 启动单个任务和启动整个队列。
- 暂停、继续、取消和取消全部执行。
- 任务切换和串行执行。
- FFmpeg 不可用时的失败状态。
- 极限压缩确认拦截。
- 执行完成或失败后写回仓储。

### 进度观测

- 解析 FFmpeg `out_time_ms` 进度字段。
- 根据视频时长计算任务进度。
- 时长缺失时保持安全状态。
- 退出码失败和输出文件缺失时标记失败。

### 媒体分析

- FFprobe 分析时长、编码、码率、分辨率、音频和容器信息。
- 源文件不存在、FFprobe 不可用或分析失败时保存错误信息。
- 分析结果写回任务并刷新状态。

### 预览和缩略图

- 预览帧生成的输入校验。
- 缺少时长、FFmpeg 不可用或命令失败时的错误处理。
- 参数变化后预览结果失效。
- 视频缩略图生成和失败缓存。

### 工作台交互和风格

- 任务配置弹窗中“已修改”和“已压缩”只在底部按钮同排左侧显示。
- 未实际改变配置时不显示“已修改”。
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
- 已有任务能从本地数据库恢复。

### 文件导入

- 点击底部 `+` 选择单个视频。
- 点击底部 `+` 选择多个视频。
- 拖拽单个视频到窗口。
- 拖拽多个视频到窗口。
- 拖拽文件夹时显示失败原因。
- 导入非视频文件时显示当前版本只支持视频的提示。

### 媒体分析和任务列表

- 新任务进入“分析中”。
- 分析成功后显示源文件信息。
- 分析失败后显示错误状态和顶部通知。
- 源文件被移动或删除后任务变成“找不到源文件”。
- 任务列表缩略图正常显示或失败后不反复生成。

### 任务配置

- 点击任务卡片打开“任务详情设置”弹窗。
- 切换清晰优先、均衡推荐、微信发送、体积优先。
- 切换自定义目标体积模式，并通过比例滑杆选择目标体积。
- 修改输出格式、视频编码和分辨率。
- 保存配置后任务使用新配置。
- 没有实质修改配置时，不应显示“已修改”。
- “已修改”和“已压缩”显示在弹窗底部按钮同排左侧，不显示在推荐方案或目标体积区域内。

### 队列和任务控制

- 点击单个任务的开始按钮能执行该任务。
- 点击底部主按钮能启动队列。
- 运行中任务显示进度。
- 运行中任务可以暂停。
- 暂停任务可以继续。
- 任务可以取消、删除和重试。
- 清空列表前出现确认弹窗。
- 清空列表会取消执行并移除任务。

### 通知和弹窗风格

- 右上角通知从右向左进入，并在关闭时播放退出动画。
- 通知边距、颜色、圆角和阴影与工作台视觉风格一致。
- 压缩确认、导入失败、清空任务和重命名弹窗使用统一工作台弹窗框架。

### 完成和结果处理

- 压缩完成后弹出完成提示。
- 完成提示显示输出文件名和输出路径。
- 点击“打开文件所在位置”可以打开 Finder、Explorer 或文件管理器。
- 失败任务保留错误信息并可重试。

### 右键菜单

- 右键任务可以打开文件所在位置。
- 右键任务可以重命名。
- 重命名为空时显示提示。
- 右键任务可以删除。

### macOS 构建验证

- `flutter build macos --release` 成功。
- `Machining.app` 中存在内置 FFmpeg / FFprobe。
- 运行 Release app 后任务使用 app 包内 FFmpeg。
- 在另一台 Apple Silicon Mac 上验证启动、导入、压缩和打开输出位置。

### Windows 构建验证

- `PowerShell -ExecutionPolicy Bypass -File scripts\build_windows.ps1` 成功。
- Release 目录存在 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe`。
- 生成 `build/windows/x64/runner/Machining-v<version>-windows-x64.zip`。
- Windows app 可以启动、导入、压缩和打开输出位置。
- GPU 编码器不可用时可以回退到软件编码。

## 内置 FFmpeg 验证

macOS：

```bash
APP="build/macos/Build/Products/Release/Machining.app"
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
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```
