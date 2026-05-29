# FrameLean（帧轻）文档中心

## 文档目的

这里是 FrameLean 的唯一文档入口，用于让开发者和 AI 快速了解：

- 产品是什么、给谁用、当前具备什么能力；
- 当前项目架构、核心模块和技术边界；
- 测试文件在哪里，如何运行测试；
- macOS 和 Windows 应用如何构建；
- 外部参考、更新日志和详细问题日志放在哪里。

阅读文档时优先区分当前事实、实现计划和历史记录：

- 当前事实放在 `product/`、`develop/`、`reference/`。
- `plans/` 保存当时的实现计划，用于追溯任务背景；如果和当前代码或 `develop/` 冲突，以当前代码和 `develop/` 为准。
- 历史记录放在 `archive/`，可能不再代表最新实现。

## 文档地图

```text
docs/
  README.md                         文档总入口和目录规范

  product/
    roadmap.md                      产品路线图和下一阶段规划

  plans/
    2026-05-19-app-settings-dialog.md
                                     历史实现计划，可能已被当前代码和 develop 文档更新

  develop/
    architecture.md                 项目架构、核心模块和架构优势
    project-workflow.md             需求讨论、分支、测试、实现、验证、文档和 PR 准备流程
    git-workflow.md                 Git 分支、worktree、提交、PR、发布和 tag 规则
    technology-stack.md             技术栈、依赖、开发环境和平台范围
    data-model.md                   数据库 schema、任务模型和设置模型
    test-plan.md                    当前自动化测试和手动验证计划

  reference/
    ffmpeg-license-distribution.md  FFmpeg、x264、GPL 路线和分发参考

  diagrams/
    generated/                      架构图、数据流图、ER 图和流程图生成产物

  archive/
    changelog.md                    面向版本的更新日志
    logs/                           详细问题定位和解决记录
```

## 命名规范

- `docs/README.md` 是唯一文档入口，子目录不再放 `README.md`。
- 当前文档使用小写 kebab-case，例如 `technology-stack.md`。
- 子目录已经表达范围时，文件名不重复目录名，例如 `product/roadmap.md` 不再额外写 `product` 前缀。
- 当前文档不加版本后缀；历史快照和过程记录移动到 `archive/`。
- 当前文档文件名统一小写；更新日志使用 `archive/changelog.md`。
- 详细问题日志使用日期前缀：`YYYY-MM-DD-short-topic.md`。

## 产品

FrameLean（帧轻）是一个桌面视频压缩应用。它把常用 FFmpeg 视频分析、预览、压缩和格式输出能力封装成图形界面，让用户不需要手写 FFmpeg 命令也能处理视频文件。

当前产品范围以视频压缩、推荐方案预设、自定义目标体积压缩、输出预估、应用默认设置和本地任务队列为主。

产品原则：

- 默认内置 FFmpeg / FFprobe，减少环境配置。
- 提供简单压缩选项，同时保留必要的自定义能力。
- 展示源文件信息、输出预估、任务进度和最终输出位置。

目标用户：

- 需要压缩课程、录屏、会议视频或屏幕录制的用户；
- 需要快速降低视频体积的内容创作者；
- 希望使用 FFmpeg 能力但不想记命令的开发者。

当前产品能力：

- 通过文件选择器或拖拽导入本地视频。
- 使用 FFprobe 分析媒体信息。
- 通过 FFmpeg 服务生成缩略图和预览相关素材。
- 配置输出格式、视频编码、编码器后端、分辨率、输出目录和输出文件名。
- 使用清晰优先、均衡推荐、微信发送、体积优先等推荐方案预设。
- 使用自定义目标体积模式，通过比例滑杆选择目标体积。
- 检测 macOS VideoToolbox 和 Windows 硬件编码后端。
- 管理任务队列的开始、暂停、继续、取消、删除、重试和重命名。
- 完成后显示输出路径，并打开 Finder、Explorer 或 Linux 文件管理器。
- 支持 macOS Apple Silicon 和 Windows x64 的 FFmpeg / FFprobe 运行时打包路径。
- 通过统一工作台弹窗框架展示确认、失败、重命名、清空和完成信息。
- 通过右上角工作台通知展示导入、分析、失败等轻量反馈。

主要用户交互：

| 用户动作 | 产品响应 | 内部处理 |
| --- | --- | --- |
| 导入文件 | 创建任务并显示在任务列表 | 校验文件、保存任务、触发媒体分析 |
| 选择任务 | 打开任务配置弹窗 | 编辑压缩模式、预设、编码、分辨率和输出配置 |
| 开始处理 | 任务进入 FFmpeg 队列 | 构建命令、启动进程、监听进度 |
| 暂停 | 挂起当前运行任务 | 挂起前台 FFmpeg 进程并保存暂停状态 |
| 继续 | 任务继续执行 | 恢复已挂起进程，或重新进入可执行队列 |
| 取消 | 停止当前执行 | 终止进程并保留任务以便重试 |
| 重命名 | 更新任务显示名 | 只修改任务记录，不修改源文件 |
| 删除 | 从列表移除任务 | 删除本地任务记录 |
| 打开文件位置 | 打开系统文件管理器 | 使用 Finder、Explorer 或 `xdg-open` |

产品路线图见 `product/roadmap.md`。

## 开发

`develop/` 合并了架构和工程流程文档。

当前技术文档：

- `develop/architecture.md`
- `develop/project-workflow.md`
- `develop/git-workflow.md`
- `develop/technology-stack.md`
- `develop/data-model.md`
- `develop/test-plan.md`

建议阅读顺序：

1. 涉及产品范围时读 `product/roadmap.md`。
2. 处理非平凡需求、bug、架构或产品方向前读 `develop/project-workflow.md`。
3. 涉及分支、worktree、提交、PR 或发布时读 `develop/git-workflow.md`。
4. 修改模块边界前读 `develop/architecture.md`。
5. 修改任务、设置、数据库或持久化行为前读 `develop/data-model.md`。
6. 新增或调整测试前读 `develop/test-plan.md`。

## 测试

自动化测试位于项目根目录 `test/`：

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

安装依赖：

```bash
flutter pub get
```

运行静态分析：

```bash
flutter analyze
```

运行全部自动化测试：

```bash
flutter test
```

运行单个测试文件：

```bash
flutter test test/ffmpeg_command_builder_test.dart
```

真实 FFmpeg / FFprobe 验证需要平台运行时文件。详细测试范围见 `develop/test-plan.md`。

## 构建

构建前建议先运行：

```bash
flutter pub get
flutter analyze
flutter test
```

### macOS

macOS 构建需要 Apple Silicon、Xcode Command Line Tools 和 FFmpeg 构建依赖：

```bash
brew install nasm pkg-config
```

准备 macOS arm64 FFmpeg / FFprobe：

```bash
scripts/build_ffmpeg_macos_arm64.sh
```

必须存在的运行时路径：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
```

开发运行：

```bash
flutter run -d macos
```

Release DMG 构建：

```bash
scripts/build_dmg_macos.sh
```

Release 产物：

```text
build/macos/Build/Products/Release/FrameLean.app
build/macos/Build/Products/Release/FrameLean-v1.1.5.dmg
```

验证 app 内置 FFmpeg 和法律资料：

```bash
APP="build/macos/Build/Products/Release/FrameLean.app"
"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -version
"$APP/Contents/Resources/ffmpeg/ffprobe" -hide_banner -version
test -f "$APP/Contents/Resources/legal/COPYING"
```

### Windows

Windows 构建需要 Visual Studio C++ desktop build tools。

必须存在的运行时路径：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

开发运行：

```powershell
flutter run -d windows
```

Release 构建：

```powershell
PowerShell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

Release 产物：

```text
build/windows/x64/runner/Release/
build/windows/x64/runner/FrameLean-v1.1.5-windows-x64.zip
```

Windows 打包脚本会调用 `flutter build windows --release`，再验证 Release 目录、内置 FFmpeg / FFprobe 和法律资料，并默认生成 zip 包。macOS DMG 和 Windows zip 文件名都会读取 `pubspec.yaml` 的语义化版本，不包含 `+build` 后缀；Windows zip 解压后顶层目录应为 `FrameLean-v1.1.5-windows-x64/`。Windows CMake 配置会把 FFmpeg / FFprobe 复制到 Release 目录的 `ffmpeg/` 下。如果运行时文件缺失，构建应失败，避免产出不完整安装包。

验证 app 内置 FFmpeg：

```powershell
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe -hide_banner -version
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe -hide_banner -version
```

## 参考资料

`reference/` 只放外部参考和许可证依据，不记录当前产品范围、实现规划或开发任务。

当前参考文档：

- `reference/ffmpeg-license-distribution.md`

处理 FFmpeg 分发、许可证合规或第三方资料时再阅读这个目录。

许可与分发资料：

- `LICENSE`
- `NOTICE`
- `legal/COPYING`
- `legal/THIRD_PARTY_NOTICES.md`
- `legal/SOURCE_OFFER.md`
- `legal/third-party/`

## 归档

`archive/` 放历史更新记录和详细问题日志，不作为当前产品或架构事实的唯一依据。

`archive/changelog.md` 记录版本级更新摘要：

- 新增内容；
- 行为变化；
- 已修复问题。

`archive/logs/` 记录更细的问题解决过程：

- 问题出在哪里；
- 根因是什么；
- 做了什么修改；
- 如何验证；
- 剩余风险或后续事项。

如果归档内容与当前文档或源码冲突，以当前文档和源码为准。
