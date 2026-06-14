# v1.2.0 Release

## 版本摘要

v1.2.0 汇总 `v1.1.5..release/v1.2.0` 的全部变更。版本重点是把 FrameLean 从以视频为主的压缩工作台扩展为视频、图片、音频统一处理工具，并完善设置、通知、输出命名、HDR 色彩和桌面发布链。发布前同时完成 Clean Architecture P0-P2 治理，减少 feature、application 和 infrastructure 之间的反向依赖。

## 主要变更

- 视频、图片、音频进入统一 `MediaTask` / `MediaTaskConfig` 模型，图片和音频支持导入、分析、配置、队列执行和完成反馈。
- NCM 使用本地 Dart 解密；MGG、MFLAC 等 QMC 变体支持随包外部适配器或 `qmc-decrypt`。
- 工作台支持深浅主题、启动主题缓存、响应式布局、任务拖拽排序和运行期间调整后续执行顺序。
- 应用设置迁移到 `/settings` 全屏页面，支持分区独立保存 / 取消、默认媒体配置、输出模板、通知偏好、缓存清理和 Windows 清理卸载。
- 新增持久化通知中心、统一应用通知、任务完成提示音、成果物文件夹动作和完成弹窗开关。
- 默认输出文件名改为可编辑模板，默认模板为 `{source}-{action}`，支持 `{source}`、`{date}`、`{version}`、`{action}`、`{codec}`、`{encoder}`；重复导入同一源文件时 `{version}` 会从 `v1` 递增，重复导出已有 `v1` 文件时优先输出 `v2` / `v3`。
- 新增视频 / 图片 / 音频元数据保留开关、真实源格式“保持原始”语义和输出配置刷新非运行任务的规则；三类媒体默认保持源格式并保留元数据，图片默认质量为 80%。
- FFprobe 扩展色彩、HDR10 和 Dolby Vision 元数据；HDR10 / HLG 使用 `zscale + tonemap` 转 SDR，保持 HDR 限定为 HEVC Main10 基础链路。
- macOS 发布目标升级为单一 Universal 2 DMG；Windows x64 同时提供便携 ZIP 和当前用户 Inno Setup 安装器。
- 文档、项目级 skills、release / delivery 工作流和法律材料目录完成治理。
- Riverpod 依赖组装迁入 `lib/app/providers/`；设置保存刷新任务改由 application use case 承担。
- 文件选择、外链、文件管理器定位和主题缓存改为 application 端口与 infrastructure 桌面实现；共享展示组件迁入 `app`。

## 修复与稳定性

- Drift 新增列迁移改为幂等，避免重复列错误。
- 修复任务排序持久化、主题首帧缓存、macOS 非焦点窗口首次点击和重复操作入口。
- 修复 QMC 上游探测、iPhone MOV 音频流选择、执行日志保留和 Windows 文件管理器路径处理。
- 修复设置分区保存失败、离开页面后的异步通知、通知 Overlay 和通知历史读取边界。
- 修复图片 / 音频任务详情误读视频配置、保持原始选项重复、输出模板来源和 HDR 色彩参数问题。
- 修复 macOS Universal 2 CI 构建 zimg 时缺少 Automake / Libtool 依赖，以及 Windows 打包脚本误把 `ffprobe.exe -version` 管道截断当作版本校验失败的问题。
- 修复 macOS Universal artifact 解包目录不稳定和 artifact zip 丢失可执行权限导致合并脚本找不到或无法执行运行时文件的问题。
- 修复 macOS Universal DMG 打包仍保留 CocoaPods 集成导致 Flutter SwiftPM 构建继续触发 `pod install`，并在 Ruby ASCII-8BIT locale 下失败的问题；macOS 工程改为 SwiftPM-only，release 脚本加入 UTF-8 和 CocoaPods 残留护栏。
- Windows CI artifact 改为分别上传便携 ZIP 与 `setup.exe` 安装器，不再把两个发布包混在同一个 artifact zip 中。
- 修复 Windows 完成提示音依赖 PowerShell 播放的风险，改为 Flutter 音频插件播放内置 asset。
- 修复 Windows / 4K 大窗口场景字体被固定压回基础字号导致显示偏小的问题。
- 移除未引用的旧设置弹窗组件和未使用的 `cupertino_icons`。

## 验证与兼容

- 发布前通过 `flutter analyze`。
- 发布前通过全量 `flutter test`，共 267 项。
- 新增并通过 Clean Architecture import 守卫测试。
- P0-P2 触达模块 76 项回归测试通过。
- 发布 workflow 和打包脚本已补齐 macOS autotools 依赖与 Windows 原生命令版本校验保护；正式 CI 需重新触发确认产物上传。
- macOS 发布链已移除 CocoaPods 工程集成，正式 CI 需确认 SwiftPM 生成的插件包参与构建且不再运行 `pod install`。
- 数据库当前 schema version 为 23；旧视频列、历史压缩模式映射和 `media_config_json` 回退仍保留。
- 主要发布平台为 macOS Universal 2 和 Windows x64；Linux / Web 不在本版本支持范围。
- 最终签名 / 公证 DMG、Intel 真机和干净 Windows x64 安装器验收需在正式发布环境完成。

## 发布产物

正式发布应生成：

```text
FrameLean-v1.2.0.dmg
FrameLean-v1.2.0-windows-x64.zip
FrameLean-v1.2.0-windows-x64-setup.exe
```

本次本地收口未生成签名、公证或 Windows 安装器产物；由对应发布脚本和 CI 在发布环境生成并验收。

## 已知风险

- Dolby Vision Profile 5 和无 HDR10 兼容层的 Dolby Vision 会被拒绝处理；当前不保留 Dolby Vision 动态元数据。
- 保持 HDR 只覆盖 HDR10 / HLG 的基础 HEVC Main10 输出，不等同于完整 HDR 母版保真。
- 图片、音频和专有音频仍需在 macOS / Windows 最终发布包中做端到端样本验收。
- 自托管更新客户端 / 服务端不属于本版本已完成发布能力。
- 队列执行器、FFmpeg 规划器和大型工作台页面的后续拆分不在 P0-P2 范围内。

## 升级与回滚说明

- 可从 v1.1.5 直接升级到 v1.2.0，启动时会按 Drift 迁移升级本地数据库。
- 升级前建议备份应用支持目录中的 `framelean.sqlite`。
- 新版继续写入旧视频兼容列以降低回滚风险，但 v1.2.0 新增的图片 / 音频配置、通知和设置字段无法由旧版本完整理解；生产回滚前应恢复数据库备份。
- 架构治理不改变用户数据格式，也不改变现有媒体处理业务语义。

## 关联记录

- Git 比较范围：`v1.1.5..release/v1.2.0`
- `CHANGELOG.md`
- `docs/releases/v1.2.0/macos-universal2.md`
- `docs/releases/v1.2.0/output-settings-and-file-name-template.md`
- `docs/releases/v1.2.0/media-task-defaults-and-metadata.md`
- `docs/releases/v1.2.0/task-completion-sounds.md`
- `docs/releases/v1.2.0/video-color-hdr-sdr.md`
- `docs/decisions/260612-macos-universal2-distribution.md`
- `docs/decisions/260614-clean-architecture-composition-root.md`
- `docs/decisions/260613-app-notification-center-boundary.md`
- `docs/decisions/260613-output-template-settings-application.md`
- `docs/decisions/260613-media-task-source-format-and-metadata.md`
- `docs/decisions/260613-task-completion-sound-playback.md`
- `docs/decisions/260613-video-color-hdr-sdr-boundary.md`
- `docs/decisions/260613-windows-installer-update-payload.md`
