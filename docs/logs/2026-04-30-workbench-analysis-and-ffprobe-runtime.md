# 2026-04-30 工作台媒体分析与 FFprobe 运行时问题

## 背景

本次继续接入工作台左侧任务列表与右侧详情信息。用户反馈：

- 视频导入列表后，必须等分析完成，右侧详情才应该显示编码、码率、分辨率、视频格式、视频时长等真实信息。
- 后续出现任务一直停留在“分析中”的问题。
- CLI 中 FFprobe 分析很快且可用，但 macOS 图形界面中提示 “FFprobe 不可用”。
- 按流程图要求，分析失败或后续处理失败时，任务不能卡在等待或分析中，应该进入失败状态，允许用户点击刷新从分析点重试。

## 本次实现

### 右侧详情同步选中任务

调整 `WorkbenchPage` 的选中任务同步逻辑：

- 左侧任务选中后，右侧详情面板使用当前选中任务的 `analysisResult`。
- 源文件信息展示：
  - 编码：`analysisResult.videoCodec`
  - 视频大小：`sourceFileFingerprint.fileSize`
  - 码率：`analysisResult.preferredBitrate`
  - 分辨率：`analysisResult.videoWidth/videoHeight`
  - 视频格式：`analysisResult.containerFormat`
  - 视频时长：`analysisResult.durationMs`
- 输出文件信息跟随当前任务配置和分析结果显示。
- 没有分析结果时显示 `-`，不再误显示默认值，例如 `MOV`。

### 导入后的分析状态

调整 `MediaTaskListNotifier` 的导入和分析流程：

- 新导入的视频会先读取源文件指纹，保存文件大小和最后修改时间。
- 任务进入 `TaskStatus.analyzing`，列表中显示“分析中”。
- FFprobe 分析成功后，写入 `MediaAnalysisResult`，任务回到 `pending`。
- 应用启动恢复任务时，如果发现缺少分析结果，或源文件指纹发生变化，也会重新进入分析流程。

### 分析失败状态

根据流程图要求，分析失败不再回到 `pending`，也不再停在 `analyzing`：

- FFprobe 不可用：任务进入 `failed`。
- FFprobe 执行失败或输出异常：任务进入 `failed`。
- 任务保留 `analysisErrorMessage`，右侧详情展示分析提示。
- UI 通过 SnackBar 通知用户具体失败原因。

### 失败后的刷新重试

补齐失败任务的重试入口：

- `WorkbenchTaskListItem` 对 `failed / cancelled / missingSource` 任务显示刷新按钮，即使任务没有分析结果。
- `WorkbenchPage` 将刷新按钮接到 `MediaTaskListNotifier.retryTaskById`。
- 重试流程：
  1. 检查源文件是否存在。
  2. 重新读取源文件指纹。
  3. 清空旧分析结果和错误。
  4. 任务进入 `analyzing`。
  5. 重新执行 FFprobe 分析。

## 遇到的问题

### 1. 任务卡在“分析中”

原因：

前一版把任务状态改成了 `analyzing`，但 `analyzeTaskById` 在发现 FFprobe 不可用时直接 `return`。这样任务不会被更新成成功或失败，UI 就会一直显示“分析中”。

解决：

- 新增 `markAnalysisUnavailable`，FFprobe 不可用时写入分析错误。
- 后续又按流程图要求改为进入 `failed`，避免用户无法继续操作。

### 2. CLI 可用，UI 中 FFprobe 不可用

原因：

CLI 从终端启动，能拿到 shell 环境中的 PATH，所以可以找到 `/opt/homebrew/bin/ffprobe`。

macOS 图形 App 的运行环境不同，不一定继承终端 PATH。更关键的是当前 App 开启了 macOS sandbox，沙盒 App 不能像 CLI 一样自由调用 Homebrew 安装在系统路径下的外部二进制。

解决：

- `LocalFfmpegLocator` 补充 Homebrew 常见路径：
  - `/opt/homebrew/bin`
  - `/usr/local/bin`
  - `/usr/bin`
- 分析前如果运行时显示 FFprobe 不可用，会刷新一次 `ffmpegRuntimeProvider`，避免旧的运行时缓存影响分析。
- 关闭 macOS Debug / Release entitlements 中的 sandbox，让当前开发阶段的 App 可以调用系统 FFmpeg / FFprobe。

后续如果需要重新开启 sandbox 或准备正式分发，需要把 FFmpeg / FFprobe 打包进 App 内部资源目录，不能再依赖 Homebrew 路径。

## 修改文件

- `lib/features/workbench/pages/workbench_page.dart`
  - 同步选中任务详情。
  - 展示分析错误提示。
  - 监听分析错误并弹出 SnackBar。
  - 接入任务刷新重试。

- `lib/features/workbench/providers/media_task_notifier.dart`
  - 导入后进入分析状态。
  - 分析成功后回到等待状态。
  - 分析失败进入失败状态。
  - 新增 `retryTaskById`。
  - FFprobe 不可用时刷新运行时并给出失败状态。

- `lib/features/workbench/widgets/workbench_task_list_item.dart`
  - 失败任务即使没有分析结果，也显示刷新按钮。

- `lib/infrastructure/services/local_ffmpeg_locator.dart`
  - 补充 macOS / Linux 常见系统路径查找。

- `macos/Runner/DebugProfile.entitlements`
  - 当前开发阶段关闭 sandbox。

- `macos/Runner/Release.entitlements`
  - 当前开发阶段关闭 sandbox。

## 验证

已执行：

```bash
flutter analyze
flutter test
```

结果：

- `flutter analyze` 无问题。
- `flutter test` 全部通过，共 37 个测试通过。

## 当前结论

这次问题不是 FFprobe 本身不可用，而是 CLI 与 macOS 图形 App 的运行环境不同。当前阶段为了继续推进功能验证，先关闭 sandbox，并让失败状态严格按流程图进入 `failed`。后续正式版本需要重新设计 FFmpeg / FFprobe 的分发方式，优先考虑随 App 打包。
