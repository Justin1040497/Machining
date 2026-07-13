# v1.2.1 Release

## 版本摘要

v1.2.1 汇总根仓库 `v1.2.0..HEAD` 的桌面客户端变更，并关联独立 `server` 仓库当前 `main@d631ad7` 的更新服务与 Admin Web 事实。应用版本为 `1.2.1+5`，主要发布平台仍是 macOS Universal 2 和 Windows x64。

本版本集中完成更新体验、任务夹批量工作流、受控并行、隐藏 partial 输出保护、媒体容器 / 编码矩阵、通知策略、快捷键和桌面关闭行为。更新服务迁移到 RuoYi-Vue-Plus 5.X + plus-ui 5.X；当前公开发布默认展示 GitHub、Gitee 或备用下载地址，客户端不直接下载安装包。原 package、COS ticket、Windows updater helper、macOS 私有 DMG 缓存和 Sparkle appcast 链继续保留，但不再是 Admin 默认发布门禁。

## 主要变更

- 更新体验形成 L1 工作台状态胶囊、L2 轻量更新通知和 L3 完整版本日志三级入口；通知按版本去重，同版本 snooze 只抑制自动弹窗。
- 客户端和通知载荷支持 GitHub、Gitee、备用下载地址。release 存在任一外部地址时只展示跳转按钮，不创建 download ticket，也不启动 package 下载或安装。
- 独立 server 迁移到 RuoYi-Vue-Plus 5.X + plus-ui 5.X，保留公开更新 API、PostgreSQL 发布 / 审计事实、Redis latest cache / ticket、可选 COS package 和 `X-Api-Key` 兼容鉴权。
- Admin Web 默认登记 Markdown / 文本版本日志与三个外部下载地址，暂时隐藏 package 上传、requirements 和制品登记；无 package 时以"日志 + 至少一个合法外部地址"作为发布门禁。
- 任务夹成为本地持久化实体：批量导入按媒体类型自动建夹，支持夹级配置、夹内面板、排序、拖入 / 移出、重命名、批量执行和聚合日志。
- 执行队列支持工作台、任务夹和单任务三种作用域，并按用户并行上限和资源守卫分配执行位；手动任务可抢占并按 FIFO 恢复。
- FFmpeg 输出先写入同目录隐藏 `.framelean-*.partial*`，通过 preflight 后执行，成功再发布到最终路径；异常退出、取消和 partial 被外部删除时能清理或尽快失败。
- 视频输出扩展到 MP4、MOV、MKV、WebM、AVI，覆盖 H.264、HEVC、VP9、AV1、ProRes、MPEG-4 Part 2 和 MJPEG，并按容器限制编码组合。
- 图片与音频压缩增加结果验收；透明视频自动走 MOV + ProRes 4444，保留 alpha 通道。
- 设置页增加通知投递策略、快捷键重映射、最大并行任务数和关闭到后台行为；Windows 使用托盘恢复，macOS 通过 Dock 重新打开。
- 架构统一为 package import + 分层 `library.dart` 白名单门面，并增加真实 `FrameLeanApp` 桌面集成烟测。

## 修复与稳定性

- 修复运行中目标或 partial 文件被删除后任务继续到末尾才失败的问题。
- 修复输出目录、权限和重名冲突在 FFmpeg 启动后才暴露的问题。
- 修复图片压缩后体积反而增大、音频输出不小于源文件仍被标记成功的问题。
- 修复透明视频被 H.264 / yuv420p 常规策略破坏 alpha 通道的问题。
- 修复 FFprobe 超时后子进程继续存活，以及 FFmpeg 无输出卡死永久占用执行位的问题。
- 修复 VideoToolbox、NVENC、QSV、AMF 会话失效后直接失败的问题，典型 external library 错误会自动重试一次。
- 修复任务失败通知直接暴露 FFmpeg stderr / exit code 的问题，用户通知改为友好原因和建议，原始细节保留在日志。
- 修复任务夹共同设置把第一个源文件名套用到全部任务输出名的问题。
- 修复快捷键录入时 Esc 退出整个设置页、设置取消 / 切换未回滚、通知控件布局和角标语义问题。
- 修复 macOS CocoaPods 发布链、Windows 安装器、更新元数据和文档口径不一致的问题。
- 修复候选范围内 `FrameLean.iss` 和版本日志页面的多余空行，使候选 diff 可通过 whitespace 检查。

## 验证与兼容

- 通过 `rtk flutter test` 全量测试，共 376 项。
- 通过更新、通知、设置、签名和下载器定向回归，共 49 项。
- 通过 `rtk flutter test integration_test/app_smoke_test.dart`，4 项桌面烟测覆盖应用外壳、设置、批次建夹、通知中心和更新入口。
- 通过 `rtk mvn -pl ruoyi-admin -am -DskipTests package`，RuoYi 27 个 reactor 模块构建成功。
- 通过 `rtk npm run build:prod`，plus-ui Admin Web 生产构建成功；存在大 chunk 提示，不影响构建完成。
- 在提供仅用于配置解析的 `SA_TOKEN_JWT_SECRET` 与 `FRAMELEAN_PUBLIC_BASE_URL` 后，通过 `rtk docker compose config`，确认 PostgreSQL、Redis、API 和公网地址变量可解析；缺少必填值时会按设计拒绝展开。
- 通过 macOS release / FFmpeg 脚本 `bash -n`，并通过两份 GitHub Actions YAML 解析。
- 通过候选工作树 `rtk git diff --check v1.2.0` 和独立 server 文档 diff 检查。
- 打包新鲜度门禁确认：macOS / Windows Actions 调用 canonical release 脚本；macOS 注入 HTTPS `FRAMELEAN_UPDATE_BASE_URL`；Windows 注入更新地址、key id、公钥和临时私钥文件；脚本继续生成 `*.update.json`，缺少配置时 fail closed。
- `flutter analyze` 当前未通过：Flutter SDK 对两个 `cacheExtent` 和一个 `axisAlignment` 用法报告 3 条弃用级 `info`。它们不是本轮文档改动引入，但在替换为新 API 前静态分析命令仍返回非零。
- Drift schema version 从 v1.2.0 的 23 升级到 29；旧媒体兼容列继续写入，`media_config_json` 仍是新配置主字段。

## 发布产物

面向用户的正式发布产物：

```text
FrameLean-v1.2.1.dmg
FrameLean-v1.2.1-windows-x64-setup.exe
FrameLean-v1.2.1-windows-x64.zip
```

Windows ZIP 是可选便携包。canonical release 脚本还会生成保留 package 链使用的元数据：

```text
FrameLean-v1.2.1.dmg.update.json
FrameLean-v1.2.1-windows-x64-setup.exe.update.json
```

当前 Admin 默认发布只需把用户下载产物发布到 GitHub、Gitee 或备用站点，再登记对应下载页；`*.update.json`、COS package 和 ticket 链只有在重新启用直接 package 更新时才进入 Admin 验收。

## 已知风险

- 正式 macOS Universal 2 DMG、Windows x64 安装器 / ZIP、签名、公证和包内运行时尚未在本轮本机生成；需要在对应 GitHub Actions runner 或真实平台完成。
- `flutter analyze` 存在 3 条 Flutter 新 SDK 弃用信息并返回非零，发布前应决定修复或接受为已知风险。
- 当前 Flutter 测试覆盖保留 package 路线，但没有专门断言"外部地址与 package 同时存在时必须绕过 ticket / 下载"的回归用例；当前结论来自源代码交叉检查。
- server `ruoyi-framelean` 当前没有针对外部地址发布门禁的模块测试；本轮只完成 Maven 编译、Admin build、Compose 解析和源码核对。
- 外部下载地址、版本日志上传、Redis latest cache、审计和反代真实 IP 尚未在生产 RuoYi / COS / Redis / 宝塔环境端到端验收。
- package 自更新、COS ticket、Windows helper、macOS 私有 DMG 缓存和 Sparkle appcast 是保留能力，不属于当前默认发布阻塞项；重新启用前必须重新做真实包验签、下载和安装回归。
- macOS 产物未签名 / 公证时仍可能触发 Gatekeeper 提示；当前外部下载 + 手动安装策略不消除该平台提示。

## 升级与回滚说明

- 可从 v1.2.0 直接升级到 v1.2.1；启动时由 Drift 把本地数据库迁移到 schema 30。schema 30 只新增 nullable `tasks.failure_json`，旧错误列继续保留用于降级兼容。
- 升级前建议备份应用支持目录中的 `framelean.sqlite`。v1.2.0 无法完整理解任务夹、通知策略、快捷键、关闭行为、输出位置模式和 partial 运行时状态；回滚前应恢复升级前数据库备份。
- 当前默认由用户从外部下载页手动安装新版；回滚时重新安装 v1.2.0，并恢复对应数据库备份。
- 已发布的媒体输出不会随数据库回滚自动删除；回滚前应检查输出目录附近是否残留 `.framelean-*.partial*`。
- server 独立部署，升级前应备份 PostgreSQL、Redis 配置和 COS 日志对象，并在生产数据副本验证 Flyway；客户端回滚不自动回滚服务端。

## 关联记录

- 根仓库 Git 比较范围：`v1.2.0..HEAD`
- 独立 server 事实快照：`main@d631ad7`
- `CHANGELOG.md`
- `CONTEXT.md`
- `docs/releases/v1.2.1/overview.md`
- `docs/releases/v1.2.1/self-hosted-update-client.md`
- `docs/releases/v1.2.1/self-hosted-update-server.md`
- `docs/releases/v1.2.1/admin-web-release-management.md`
- `docs/decisions/260710-external-download-default.md`
- `docs/develop/architecture.md`
- `docs/develop/data-model.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
- `scripts/README.md`
