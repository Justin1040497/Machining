# 有效决策索引

这里列出当前仍有效的重要决策。正文放在 `docs/decisions/`，版本事实说明放在 `docs/releases/`。

| 日期 | 决策 | 状态 | 正文 | 关联事实 |
| --- | --- | --- | --- | --- |
| 260710 | 公开更新默认展示 GitHub / Gitee / 备用下载地址，客户端不直接下载安装包；原 package 自更新链继续保留但不再作为发布必填 | 有效 | `docs/decisions/260710-external-download-default.md` | `CONTEXT.md`、`docs/releases/v1.2.1/self-hosted-update-client.md`、`docs/releases/v1.2.1/self-hosted-update-server.md`、`docs/develop/architecture.md`、`docs/develop/test-plan.md` |
| 260623 | 更新提示收敛为 L1 工作台状态胶囊、L2 轻量通知弹窗和 L3 完整版本日志页，同版本 snooze 只抑制自动弹窗 | 有效 | `docs/decisions/260623-update-ux-redesign.md` | `CONTEXT.md`、`docs/releases/v1.2.1/self-hosted-update-client.md`、`docs/develop/architecture.md`、`docs/develop/test-plan.md` |
| 260623 | 采用单 package + barrel 白名单封装方案，7 个 `library.dart` 门面统一跨层导入，永久禁止相对路径 | 有效 | `docs/decisions/260623-library-barrel-import-architecture.md` | `docs/develop/architecture.md` |
| 260620 | 托管更新配置不以隐藏文件为安全边界，保留 Windows 安装器和 macOS 手动 DMG package 路线 | 部分被 260710 取代 | `docs/decisions/260620-managed-update-and-sparkle.md` | `docs/develop/technology-stack.md`、`docs/releases/v1.2.1/self-hosted-update-client.md`、`docs/releases/v1.2.1/self-hosted-update-server.md` |
| 260619 | 共享重排列表采用项目内 Flutter 3.41.2 fork，通过公共 facade 提供 gap 与外部 drop 能力 | 有效 | `docs/decisions/260619-shared-reorderable-list.md` | `CONTEXT.md`、`docs/develop/architecture.md`、`docs/develop/test-plan.md` |
| 260616 | 更新入口采用设置关于栏、通知中心和工作台顶部持续入口，服务端 Redis 只保存短期协作状态 | 部分被 260710 取代 | `docs/decisions/260616-self-hosted-update-client-server-flow.md` | `CONTEXT.md`、`docs/develop/architecture.md`、`docs/develop/data-model.md`、`docs/develop/technology-stack.md`、`docs/develop/test-plan.md` |
| 260614 | Riverpod 依赖装配归属 `app` composition root，平台能力通过 application port 接入，跨功能展示组件归属 `app` | 有效 | `docs/decisions/260614-clean-architecture-composition-root.md` | `docs/develop/architecture.md`、`docs/develop/test-plan.md` |
| 260613 | 应用通知统一由 `AppNotificationManager` 持久化，临时浮层和通知中心分离 | 有效 | `docs/decisions/260613-app-notification-center-boundary.md` | `docs/develop/architecture.md`、`docs/develop/data-model.md` |
| 260613 | Windows 使用当前用户 Inno Setup 安装器作为自托管更新载荷，ZIP 仅作为便携分发备用 | 有效 | `docs/decisions/260613-windows-installer-update-payload.md` | `CONTEXT.md`、`docs/develop/technology-stack.md`、`docs/develop/test-plan.md` |
| 260613 | 输出文件名使用英文变量模板，输出配置保存刷新非运行任务，运行中任务保留执行快照 | 有效 | `docs/decisions/260613-output-template-settings-application.md` | `docs/releases/v1.2.0/output-settings-and-file-name-template.md` |
| 260613 | 媒体任务保持原始只保存真实源格式和布尔模式，视频 / 图片 / 音频元数据默认保留 | 有效 | `docs/decisions/260613-media-task-source-format-and-metadata.md` | `docs/releases/v1.2.0/media-task-defaults-and-metadata.md` |
| 260613 | 任务完成音效使用 Flutter 音频插件播放内置 WAV，不启动 PowerShell | 有效 | `docs/decisions/260613-task-completion-sound-playback.md` | `docs/releases/v1.2.0/task-completion-sounds.md` |
| 260613 | 视频色彩修复默认采用 zimg HDR 转 SDR，保持 HDR 限定为 HDR10/HLG HEVC Main10 | 有效 | `docs/decisions/260613-video-color-hdr-sdr-boundary.md` | `docs/releases/v1.2.0/video-color-hdr-sdr.md` |
| 260612 | macOS 使用单一 Universal 2 DMG 支持 x86_64 / arm64，Windows 继续只支持 x64 | 有效 | `docs/decisions/260612-macos-universal2-distribution.md` | `docs/releases/v1.2.0/macos-universal2.md` |
| 260608 | 项目级 skills 从阶段拆分改为职责拆分，临时计划进入 `.workspace/` | 有效 | `docs/decisions/260608-project-skill-workflow.md` | `docs/releases/v1.1.5/project-skills-workflow.md` |
| 260608 | 文档信息架构改为上下文、工作区、版本事实、决策和经验总结 | 有效 | `docs/decisions/260608-docs-information-architecture.md` | `docs/releases/v1.1.5/repository-structure.md` |
| 260607 | 任务拖拽排序先乐观更新 UI，再后台持久化排序 | 有效 | `docs/decisions/260607-task-reorder-optimistic-update.md` | `docs/releases/v1.1.5/workbench-theme-and-reorder.md` |
| 260607 | Drift 新增列迁移统一使用幂等 `_safeAddColumn` | 有效 | `docs/decisions/260607-drift-migration-safe-add-column.md` | `docs/develop/data-model.md` |
| 260606 | 仓库结构保留 Flutter 根工程，不迁移到 monorepo | 有效 | `docs/decisions/260606-repository-structure.md` | `docs/releases/v1.1.5/repository-structure.md` |
