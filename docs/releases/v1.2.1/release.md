# v1.2.1 Release

## 版本摘要

v1.2.1 汇总 `v1.2.0..develop/v1.2.1` 的已提交历史和 release 前工作区收口。相对 v1.2.0，本版本不再把重点放在视频 / 图片 / 音频统一任务模型、输出模板、HDR / SDR、Universal 2 和基础设置 / 通知中心；这些已经是 v1.2.0 基线能力。v1.2.1 的重点是把自托管更新、任务夹批量工作流、受控并行、隐藏 partial 输出保护、通知策略 / 快捷键 / 关闭到后台和更完整的视频容器矩阵推进到 release 候选状态。

本版本仍按 macOS Universal 2 和 Windows x64 作为主要发布平台。正式发布前，需要在真实 macOS、Windows、COS、Redis 和宝塔反代环境中完成发布产物和更新链路验收；macOS 默认采用手动 DMG 下载，不把 Apple Developer ID 证书作为检查更新 / 下载的前置条件。

## 主要变更

- 自托管更新进入客户端主流程：设置关于栏、工作台顶部入口、通知中心、版本日志页面、托管更新配置、Windows 断点下载 / Ed25519 验签 / updater helper、macOS 版本日志 + DMG 下载到下载目录和服务端 release / download ticket 接口完成对接；server v1.0.0 和 Admin Web 版本管理作为 v1.2.1 发布链路事实记录。
- 任务夹批量工作流进入工作台：批量导入按媒体类型自动建夹，任务夹支持持久化、夹级配置、左侧夹内任务面板、夹内排序、拖入 / 移出、重命名、清空、批量开始 / 暂停 / 重试和聚合日志。
- 执行队列改为受控并行：应用设置保存最大并行任务数，队列按工作台、任务夹、单任务三种执行语义调度，并通过资源守卫按设备状态降级实际执行位。
- 输出链路增加隐藏 partial 保护：FFmpeg 写入同目录 `.framelean-*.partial*`，成功后发布到最终路径；应用启动会清理中断输出，运行中发现 partial 被删除或移动会尽快失败并给出明确提示。
- 输出位置模型细化为系统设置、源文件旁和自定义目录；旧空目录语义迁移为源文件旁，新任务默认跟随系统设置，执行时读取最新应用设置。
- 视频输出矩阵扩展到 MP4、MOV、MKV、WebM、AVI；编码覆盖 H.264、HEVC、VP9、AV1、ProRes、MPEG-4 Part 2 和 MJPEG，并在命令构建阶段按容器限制可用编码。
- 图片和音频压缩增加结果验收：图片压缩无效时按策略 fallback 到更合适格式，音频压缩输出不小于源文件时不会再误判成功。
- 通知系统增加投递策略：任务结果、更新和重要失败默认持久通知，普通交互和保存成功默认临时通知，用户可以按事件选择通知、临时通知或不通知。
- 快捷键系统进入应用设置：支持添加文件 / 文件夹、开始 / 暂停、返回 / 关闭顶层界面、打开设置和打开通知中心，并允许用户重新绑定。
- 桌面关闭行为可配置：默认关闭到后台；Windows 使用托盘恢复 / 退出，macOS 通过 Dock 重新打开隐藏窗口，显式退出时会确认运行任务并清理 partial 输出。
- macOS 发布链从 v1.2.0 的 SwiftPM-only 调整回 CocoaPods 插件集成；`pubspec.yaml` 固定关闭 Flutter Swift Package Manager，CI 和 DMG 脚本同步校验 CocoaPods 工程引用。

## 修复与稳定性

- 修复用户在任务运行中删除正在写入的目标文件时，进度继续跑到结尾才失败的问题。
- 修复透明视频被常规 H.264 / yuv420p 策略破坏 alpha 通道的问题；透明输出固定走 MOV + ProRes 4444。
- 修复图片压缩在任意质量百分比下可能越压越大的问题。
- 修复音频压缩输出不小于源文件仍被标记成功的问题。
- 修复输出路径、目录权限或重名冲突在 FFmpeg 启动后才暴露的问题，改为启动前 preflight 并为任务追加可见策略标签。
- 修复旧任务空输出目录语义不清的问题，避免“系统设置”和“源文件旁”在迁移后混淆。
- 修复任务结果、设置保存和普通交互通知无法区分持久 / 临时投递的问题。
- 修复快捷键录入时 Esc 误退出整个设置页、通知设置下拉框高度过矮和通知投递方式未垂直居中的交互问题。
- 修复 macOS 发布链文档、CI 和脚本仍按 SwiftPM-only 口径描述的问题，当前 release 候选统一为 CocoaPods。

## 验证与兼容

- release 前本地已通过 `rtk dart format lib test tool`、`rtk flutter analyze`、`rtk git diff --check`。
- release 前本地已通过 `rtk bash -n scripts/release/build_dmg_macos.sh`、`rtk bash -n scripts/build/build_ffmpeg_macos_arch.sh`、`rtk bash -n scripts/build/build_ffmpeg_macos_universal.sh`。
- release 前本地已通过设置、通知、输出 preflight、FFmpeg command builder、执行队列、工作台底栏和任务夹 / 任务配置 Widget 定向回归，共 205 项测试。
- release 前本地已通过 `rtk flutter test` 全量测试，共 354 项。
- 数据库 schema version 从 v1.2.0 的 23 升级到 29，新增任务夹、任务策略标签、并行上限、文件夹扫描深度、输出体积、通知策略、快捷键和关闭行为字段。
- 旧视频兼容列继续写入，`media_config_json` 仍是新媒体配置主字段；回滚到 v1.2.0 前应恢复数据库备份。
- macOS 发布链当前依赖 CocoaPods `Podfile`、`Podfile.lock` 和 Runner workspace Pods 引用；DMG 脚本会校验 Universal FFmpeg、运行时和法律资料布局。
- Windows 更新自动安装覆盖 `windows-installer` 当前用户安装器链路；macOS 更新默认通过 JSON latest / ticket 检查和下载 DMG，保存到用户下载目录后由用户手动安装。

## 发布产物

正式发布应生成：

```text
FrameLean-v1.2.1.dmg
FrameLean-v1.2.1.dmg.update.json
FrameLean-v1.2.1-windows-x64.zip
FrameLean-v1.2.1-windows-x64-setup.exe
```

macOS DMG 仍应是 Universal 2 产物，包内主应用、Flutter 运行时、FFmpeg、FFprobe 和 qmc-decrypt 需要同时包含 x86_64 与 arm64 架构。macOS DMG 可直接登记到 Admin Web；当前手动 DMG 路线只要求文件、size 和 SHA-256，Sparkle `sign_update` 元数据可选。Windows x64 继续提供便携 ZIP 和当前用户安装器；其中 `windows-installer` 安装器是自托管更新客户端的自动更新目标包，ZIP 主要用于手动下载和留存。

COS 上传、Redis ticket、宝塔反代、Admin Web 发布确认和客户端检查更新 / 下载 / 安装链路属于正式发布环境验收，不塞入普通 PR CI。Apple Developer ID 签名 / 公证会改善 macOS 安装信任体验，但不是当前手动 DMG 更新链路的阻塞项。

## 已知风险

- 发布构建必须注入 Windows 更新验签公钥；缺少真实公钥时开发构建可以检查更新，但不能视为 Windows 生产更新链路验收完成。
- macOS 手动 DMG 不自动替换正在运行的应用。没有 Developer ID 签名 / 公证时，用户首次打开 DMG 或 App 仍可能遇到 Gatekeeper 提示，需要发布说明明确。
- Sparkle CocoaPods 依赖需要在可访问 CocoaPods trunk CDN 的环境中执行 `pod install` 更新 `macos/Podfile.lock`。
- COS 私有桶、预签名上传 / 下载、Redis ticket TTL、latest cache 清理和反代真实 IP 需要在部署环境做端到端验收。
- Dolby Vision Profile 5 和无 HDR10 兼容层的 Dolby Vision 仍是高风险素材；当前不保留 Dolby Vision 动态元数据。
- CRF、VP9、AV1、ProRes、AVI 兼容参数需要继续用真实素材校准，尤其是体积、速度和播放器兼容性的平衡。
- `workbench_page.dart` 和 `task_configuration_dialog.dart` 体量偏大，release 前不做大拆分；后续应作为 UI / 状态边界治理 backlog 处理。

## 升级与回滚说明

- 可从 v1.2.0 直接升级到 v1.2.1，启动时会按 Drift 迁移升级本地数据库。
- 升级前建议备份应用支持目录中的 `framelean.sqlite`。
- v1.2.1 新增的任务夹、通知策略、快捷键、关闭行为、输出位置模式和隐藏 partial 运行时状态无法由 v1.2.0 完整理解；生产回滚前应恢复升级前数据库备份。
- 回滚后已发布到最终路径的媒体文件不会被数据库回滚自动删除；隐藏 partial 文件属于运行时保护文件，异常退出后应由新版启动清理，手动回滚前可检查输出目录附近是否残留 `.framelean-*.partial*`。
- Windows 更新失败时优先保留下载包和安装器日志，回滚到旧版安装器前确认当前进程已经退出，避免覆盖安装被占用文件中断。

## 关联记录

- Git 比较范围：`v1.2.0..develop/v1.2.1`
- `CHANGELOG.md`
- `CONTEXT.md`
- `docs/releases/v1.2.1/overview.md`
- `docs/releases/v1.2.1/self-hosted-update-client.md`
- `docs/releases/v1.2.1/self-hosted-update-server.md`
- `docs/releases/v1.2.1/admin-web-release-management.md`
- `docs/decisions/260616-self-hosted-update-client-server-flow.md`
- `docs/decisions/260619-shared-reorderable-list.md`
- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
- `docs/reference/ffmpeg-license-distribution.md`
