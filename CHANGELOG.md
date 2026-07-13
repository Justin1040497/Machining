# 更新日志

主要记录 FrameLean 的版本级变化。更名前的历史内容保留在带旧产品版本号的条目中。

这里记录面向发布、维护和回溯的简洁摘要，不记录每日流水账。可复用经验写入 `docs/lessons.md`，重要决策写入 `docs/decisions/`，版本形成的稳定事实设计写入 `docs/releases/`。

## 记录格式

```text
YYYY-MM-DD｜vX.Y.Z｜Release 或 No Release
当天更新概要

### Added

- 新增内容

### Changed

- 更新内容

### Fixed

- 修复内容

### Verified

- 验证内容
```

同一天的多个提交会合并整理为简洁 bullet

## 2026-07-14｜v1.2.1｜No Release

新增工作台背景动态引导系统：使用 Canvas 手绘箭头、可组合内容组和场景调度器，根据空队列、有任务、列表空间和窗口尺寸动态调整背景提示，不改变任务列表和底栏的前景交互。

### Added

- 新增 `features/workbench/guide/`，按 `arrow / content / models / scheduler` 拆分动态涂鸦箭头、引导内容组、统一坐标模型和场景调度。
- 空队列显示导入图标、提示文案和指向添加按钮的动态箭头；有任务且列表空间充足时显示任务操作与全部开始两组提示。
- 空队列背景板支持双击打开现有任务导入入口。
- 新增箭头几何与目标移动、Guide Scheduler、场景切换、空间隐藏和空背景双击回归测试。

### Changed

- 工作台锚点通过 `GlobalKey + RenderBox.localToGlobal` 统一转换到背景 Guide Stack 坐标系；任务数量、窗口尺寸和按钮布局变化会重新测量。
- 首次显示使用手绘 PathMetric 动画；同场景任务增删只执行 700ms `easeOutCubic` 位置 Tween；空队列和任务场景切换使用 350ms Fade Out、100ms 间隔和 600ms Fade In。
- 列表可滚动或最后一行下方不足 132px 时隐藏任务场景提示，整个引导层使用 `IgnorePointer` 保持前景拖拽、框选、点击和底栏操作不变。

### Fixed

- 修复引导箭头过长、终点落入任务卡片 / 底栏 / 按钮内部被上层组件遮挡的问题：三条箭头改用安全视觉终点（任务下方约 30 px、开始按钮上方约 22 px、列表视口底部上方 20 px），叠加 `maxLength` 限长（任务 270 / 全部开始 180 / 添加按钮 270 / 默认 280）、`curveBias` 单段三次贝塞尔曲线偏移与 `clipRect` 安全裁剪区。
- 箭头头改为开放式涂鸦样式（两条不对称外轮廓 + 两条内部排线，不填充、不闭合），长度约 12～17 px，避免被任务卡片或底栏盖住。

### Verified

- `flutter test` 431 项全部通过，包含新增 13 项工作台 Guide 箭头、调度、加载切换、场景和双击集成测试。
- `flutter analyze` 无新增 warning / error；仍有 5 项来自当前主线的 info 级提示。
- 通过浅色工作台 1100×760 视觉预览，检查空队列和任务场景的箭头曲率、层级、目标边缘与文本布局。
- 引导箭头修复后重跑 `flutter analyze`（guide 作用域与对应测试）无 issue，`test/workbench_guide_arrow_test.dart` 2 项通过。

## 2026-07-13｜v1.2.1｜No Release

稳定导入到视频导出的核心链路：统一导入状态语义，修复资源等待时的递归补位和并发分析状态，强化最终输出发布校验，并在兼容现有门面接口的前提下拆分 FFmpeg 执行内核职责。

### Added

- 新增批量媒体导入 use case，单文件、批量、拖拽和文件夹导入共享任务创建规则与单次批量持久化。
- `MediaWorkScheduler` 新增只读容量变化流；新增非重入、可合并的 `ExecutionSlotCoordinator` queue pump。
- 新增 `TaskProcessLifecycle` 和 `TaskResultFinalizer`，分别承接进程生命周期与结果发布职责。
- 新增 `awaitingAnalysis` 任务状态、统一执行准入语义和结构化 `TaskFailure`；Drift 升级到 schema 30，以 `failure_json` 跨重启保存失败阶段、错误码、用户提示、技术摘要和可重试性。
- 新增并发分析、租约恢复补位、输出可用性、旧数据库升级、快速分析 UI 刷新和桌面导出闭环回归测试。

### Changed

- 应用构建号升级到 `7`，版本保持 `1.2.1`。
- 新导入任务统一先持久化为 `awaitingAnalysis`，分析队列取得执行位后转为 `analyzing`，有效分析结果保存后才进入表示“等待开始”的 `pending`。
- 单任务、任务夹、连续队列、插队和 Runner 最终防御统一执行准入；未分析任务返回 `notReady`，不会申请编码租约、准备输入、预检输出、构造命令或启动进程。
- `failed` 保持唯一失败状态；分析失败重试回到 `awaitingAnalysis`，执行 / 发布失败且分析仍有效时回到 `pending`，通知使用用户提示与推导出的恢复动作，技术摘要和完整 stderr 留在日志路径。
- 分析队列使用活跃任务 ID 集合跟踪并发任务，停止时等待活跃清理完成后再关闭状态流。
- FFmpeg 队列在租约不足时立即返回 `queued` 并结束当前补位轮次；租约释放或资源压力恢复后由异步 queue pump 自动补位。
- 工作台的最终文件定位编排迁入 `WorkbenchResultHandler`，页面保留交互与展示职责。

### Fixed

- 修复资源被分析任务占用时重复选择、重复准备输入、递归补位或忙循环的问题。
- 修复并发分析时只能查询和取消单个当前任务，以及队列关闭后异步回调的问题。
- 修复快速分析完成后仓储已更新但工作台仍停留在旧状态的问题。
- 修复发布失败或最终文件不可读时仍可能保存 `completed` 和无效 `outputPath` 的问题。

### Verified

- `flutter test` 418 项全部通过；覆盖导入、分析、执行硬准入、容量补位、队列顺序、暂停 / 取消、结构化失败、输出发布和 schema 21 / 24 / 28 / 29 升级到 schema 30。
- macOS Debug 桌面集成烟测 5 项全部通过并正常退出；新增场景完成选择视频、分析、启动、模拟进程写出、发布、完成卡片和打开最终输出位置。
- `flutter analyze` 零新增问题；仍有 5 项来自当前主线的 info 级提示。
- 正式安装包的 Apple Silicon、Intel Mac 和 Windows x64 三轮真实视频矩阵仍是发布前硬门槛，尚未在本工作区执行。

## 2026-07-12｜v1.2.1｜No Release

修复媒体分析卡死和任务执行死锁：调度器新增非阻塞 `tryAcquire` 方法，中断 `_serializeCommand` 串行命令锁与 `scheduler.acquire()` 无限等待形成的死锁链；同时修复分析队列永久去重、暂停不释放编码槽位、导入过早写入 `analyzing` 状态和进度假活检测问题。

### Added

- `MediaWorkScheduler` 新增 `tryAcquire()` 非阻塞方法：资源不足时立即返回 `null`，避免在串行命令区内创建永不完成的 `Completer` 导致死锁。
- `LocalFfmpegProcessObserver` 新增 `lastProgressAt` 时间戳和 `touchProgress()` 回调：区分 `out_time_ms` 变化产生的有效进度和 stderr 日志输出，防止"持续输出警告但编码已卡死"的假活状态。

### Changed

- `FfmpegTaskQueueRunner.observeExecution` 重构为两阶段：先在串行命令外释放调度器租约，再进入 `_serializeCommand` 收尾清理；从根源上打破 `_serializeCommand` ↔ `scheduler.acquire()` 的循环等待。
- `FfmpegTaskQueueRunner.startTask` 改用 `tryAcquire()` 替代 `acquire()`：资源不足时立即返回 `queued` 状态并释放已准备的 IO 资源，不阻塞后续任务。
- `FfmpegTaskQueueRunner._releaseSchedulerLease` 改为幂等：立即清空 `execution.schedulerLease` 后再 best-effort 释放租约，避免多次调用或异常路径下的二次释放。
- `FfmpegTaskQueueRunner._pauseExecution` 暂停时释放活跃编码租约，让其他任务可以使用编码槽位；恢复时通过 `tryAcquire()` 重新申请。
- `MediaAnalysisQueue.enqueue` / `enqueueAll` 去重从永久 `_allTaskIds` 改为基于条目状态的判断：只阻止 `pending` / `analyzing` 重复入队，允许 `completed` / `failed` / `cancelled` 重新分析。
- `ImportMediaTaskUseCase` 导入时任务初始状态从 `analyzing` 改为 `pending`，避免分析队列尚未接手前就写入中间态。
- `LocalInterruptedOutputCleaner` 新增 `analyzing` → `pending` 恢复：应用重启后旧 FFprobe 进程已不存在，恢复为待分析而不标记失败。
- `FfmpegTaskQueueRunner.resumeExecution` 恢复时如果租约已释放会重新申请；`_startOutputMonitor` 传递 `touchProgress` 回调以启用双重 stall 检测。
- 暂停进程出错时通过 `addPostFrameCallback` 重新入队被抢占任务，避免在暂停回调中直接修改执行队列。

### Fixed

- 修复导入媒体后任务长期停留在"分析中"且无法开始执行的问题。
- 修复点击"开始任务"后应用卡死的问题（根因：`_serializeCommand` 串行区内调用 `scheduler.acquire()` 创建永不完成的 `Completer`，而租约释放也需要进入同一串行区）。
- 修复暂停运行任务后编码槽位不释放、其他等待任务无法启动的问题。
- 修复分析失败后任务被永久去重、无法重新分析的问题。
- 修复 FFmpeg 进程持续输出 stderr 但无有效进度时 stall 检测不触发的问题。

### Verified

- 通过 `flutter analyze`，零新增 error/warning（仅 5 项已存在的 info 级弃用提示）。
- 通过 `flutter test`，401 项测试全部通过。
- 通过 `dart format` 覆盖本次修改的全部 6 个文件。

## 2026-07-11｜v1.2.1｜No Release

修复 Windows 输出权限误判与错误分类：输出预检不再因 attrib.exe 失败阻断任务，错误提示从统一"无权限"改为按阶段和原因分类，并建立输出失败诊断模型和重试机制。

### Added

- 新增 `OutputFailure` 错误诊断模型，包含 `OutputFailureStage`（12 个阶段）和 `OutputErrorCode`（15 个错误码），区分目录创建、探针测试、FFmpeg 启动、文件发布等不同失败环节。
- 新增 `mapWindowsOsErrorCode()`、`isPermissionDeniedText()` 和 `isSecuritySoftwareBlockText()` 辅助函数，支持中英文双语错误关键词识别。
- 新增 output_failure_test.dart（22 项）和 output_preflight_service_test.dart 探针残留、只读目录与隐藏属性边界测试（共 8 项）。

### Changed

- `attrib.exe` 隐藏属性设置从致命操作改为 best-effort：失败时只输出 stderr 警告，不再阻断任务。
- 输出目录预检改用“创建 + 重命名 + 删除”唯一探针文件替代仅创建检测，并确保预检后无残留文件。
- 不再预创建工作文件，交由 FFmpeg 自行创建，避免提前占用文件句柄。
- 文件发布阶段（`rename`）在 Windows 上对 sharing violation / access denied 增加有限重试（100ms、250ms）。
- Windows manifest 显式声明 `requestedExecutionLevel asInvoker`，明确不使用管理员权限启动。
- FFmpeg 进程启动路径确保为绝对路径。
- `defaultExportPath` 不再回退到 `Directory.current`。

### Fixed

- 修复 Windows 上 `attrib.exe` 失败导致所有输出任务被误判为"没有权限"的 P0 问题。
- 修复输出目录不可写时笼统报告"输出目录不可写"的问题，现按实际原因（权限拒绝 / 安全软件拦截 / 路径无效 / 文件占用 / 磁盘不足）给出针对性提示。
- 修复错误分类仅匹配中文关键词、无法识别 FFmpeg 英文 stderr 的问题，现所有检查均为中英文双语。
- 修复管理员模式下仍显示错误权限提示的问题，改为非阻断通知。
- 修复 manifest 中 `trustInfo` 与新内容重复的无效 XML 问题。

### Verified

- 通过 `dart analyze lib/`，静态分析零新增 issue。
- 通过 `flutter test test/output_preflight_service_test.dart`、`test/output_failure_test.dart` 和 `test/ffmpeg_task_queue_runner_test.dart`，共 61 项定向回归。

### Batch Import Stability & Global Resource Scheduling

批量导入稳定性与全局资源调度改造：引入全局媒体分析队列、资源调度器和动态资源监控，解决批量导入 50 个视频时闪退/黑屏/卡顿问题，以及两个大型任务并行时的稳定性问题。

### Added

- 新增 `MediaAnalysisQueue` 全局媒体分析队列，确保任意时刻活跃 FFprobe 进程数 <= 1，支持 FIFO、taskId 去重、取消等待和状态回调。
- 新增 `MediaWorkScheduler` 全局资源调度器，使用租约模式管理 encode/analyze/thumbnail/preview 等不同工作类别的资源分配，支持优先级和并发限制。
- 新增 `MediaResourceMonitor` 轻量系统资源监控器，每 1 秒采样可用内存，计算正常/压力/严重压力三级压力级别，支持迟滞恢复机制（12 秒稳定窗口），覆盖 macOS/Windows/Linux。
- 新增 `MediaTaskRepository.loadTaskById()`、`loadTasksByIds()` 和 `insertTasks()` 接口与实现，支持按 ID 精确查询和批量写入。

### Changed

- `MediaTaskNotifier.createDraftsFromPaths` 重写为批量模式：一次性读设置和任务，内存创建，单事务批量写入，避免每文件一次 DB IO。
- `MediaTaskNotifier.analyzeTasksInBackground` 和 `analyzeTaskById` 统一路由到 `MediaAnalysisQueue`，消除多个后台分析循环重叠问题。
- `FfmpegTaskQueueRunner.startTask` 通过 `MediaWorkScheduler.acquire()` 申请 `MediaWorkKind.encode` 租约，任务结束/失败/取消时在所有退出路径统一释放租约。
- FFmpeg 进度回调改用 `loadTaskById()` 替代 `loadAllTasks()`，数据库进度写入节流为每 1 秒最多一次。
- `LocalExecutionResourceGuard` 扩展 Windows（wmic）和 Linux（/proc/meminfo）内存检测。
- FFprobe stdout/stderr 增加缓冲区上限（4MB / 512KB），防止异常文件导致内存无限增长。
- `MediaWorkScheduler` 集成 `MediaResourceMonitor`：压力状态下自动停止启动新后台工作（分析/缩略图/预览），不启动第二编码任务；严重压力下仅允许前台编码。

### Verified

- 通过 `flutter analyze`，零新增 error/warning（仅 5 项已存在的 info 级弃用提示）。
- 通过 `flutter test`，401 项测试全部通过。

## 2026-07-10｜v1.2.1｜No Release

收口 v1.2.1 当前更新发布策略：公开 release 默认展示外部下载入口，原 package 自更新链保留但不再作为 Admin 默认发布路径。

### Changed

- 客户端支持 GitHub、Gitee 和备用下载地址；release 存在任一外部地址时只展示日志与跳转按钮，不创建 download ticket，也不直接下载安装包。
- RuoYi 更新服务允许“版本日志 + 至少一个外部下载地址”发布；三类 package requirement 调整为非必填，登记 package 时仍保留平台、size、SHA-256、签名和 COS 对象校验。
- Admin Web 默认展示下载地址登记，暂时隐藏 COS package 上传、制品要求和制品登记界面；Markdown / 文本版本日志仍通过 COS 上传。
- canonical macOS / Windows release 脚本和 GitHub Actions 继续按保留 package 链 fail closed，要求更新配置完整并生成 `*.update.json`。
- 新增外部下载优先决策，并同步项目上下文、架构、数据模型、测试计划、版本事实和 server README。

## 2026-07-04｜v1.2.1｜No Release

校准 RuoYi-Vue-Plus 后台和自托管更新部署文档，明确旧 Admin Web 已废弃以及历史缺包版本的归档策略。

### Changed

- 更新 v1.2.1 Admin Web / 自托管更新服务文档，把旧 React Admin 主密码和 challenge 登录描述替换为当前 RuoYi / Sa-Token 登录态与 `X-Api-Key` 兼容鉴权。
- 明确自动更新发布要求：`windows-installer` 和 `macos-universal2` 是当前客户端可见必填包，缺少 Windows `.exe` 安装器的历史版本只能作为 draft / 归档留存，不进入 `/latest` 发布通道。
- 校准技术栈文档中的后台鉴权和会话存储事实，标注 `admin_auth_config` 仅为历史表。

### Verified

- 通过文档 diff 审查和打包 / 更新配置新鲜度检查，确认 GitHub Actions、本地 release 脚本和当前文档中的更新地址、签名和制品路径语义一致。

## 2026-06-28｜v1.2.1｜No Release

重写自托管更新后端，迁移到 RuoYi-Vue-Plus 5.X + plus-ui 5.X，保留客户端更新协议、COS 私有桶分发、Redis 短期票据和既有发布数据模型。

### Added

- 新增 `ruoyi-modules/ruoyi-framelean` 业务模块，提供公开更新 API、Sparkle appcast、发布管理、COS 预签名上传 / 下载、下载票据、更新检查审计、下载审计和 IP 屏蔽。
- 新增 plus-ui FrameLean 后台页面：发布版本、更新审计、运行诊断，并把旧 `/web` 重定向到新后台入口。
- 新增 PostgreSQL Flyway 迁移，导入 RuoYi 系统表并保留 `releases`、`release_packages`、`release_artifact_requirements`、`download_events`、`update_check_events` 和 `ip_block_rules`。

### Changed

- `server/` 从旧 Kotlin + 手写 React Admin 改为 RuoYi-Vue-Plus 5.X 多模块后端和官方 plus-ui 5.X 前端；旧主密码 / challenge 登录和 `admin_auth_config` 认证流废弃。
- 部署配置改为 PostgreSQL + Redis + COS + Sa-Token secret 的 RuoYi 单容器 API，Dockerfile 改为 plus-ui build + `ruoyi-admin` Maven build。
- `FRAMELEAN_PUBLIC_BASE_URL` 作为公网根地址，旧 `FRAMELEAN_UPDATE_BASE_URL` 继续作为 fallback。

### Verified

- 通过 `rtk mvn --settings /private/tmp/framelean-maven-settings.xml -Dmaven.wagon.rto=180000 -Dmaven.wagon.http.retryHandler.count=3 -pl ruoyi-admin -am -DskipTests package`，RuoYi 后端和 `ruoyi-framelean` 模块编译成功。
- 通过 `rtk npm install --registry=https://registry.npmmirror.com --fetch-timeout=60000 --fetch-retries=1` 安装 plus-ui 依赖；Node 23 下仅有 engine warning。
- 通过 `rtk npm run build:prod`，plus-ui 生产构建成功。
- 通过 `rtk proxy env SA_TOKEN_JWT_SECRET=test-secret FRAMELEAN_PUBLIC_BASE_URL=https://framelean.example.com docker compose config`。
- 通过 `rtk git diff --check`。

## 2026-06-26｜v1.2.1｜No Release

修复任务夹共同设置会错误统一覆盖每个任务输出文件名的 bug。

### Fixed

- 修复任务夹共同设置下发后，夹内所有任务的 `outputFileName` 都被套用第一个任务源名渲染结果的问题：`ApplyTaskFolderConfigUseCase` 现注入 `AppSettingsRepository`，对每个可应用任务按全局模板 + 各自源名重新渲染输出文件名，`{version}` 保留各任务自己的处理序号，`{date}` 用下发时刻。

### Verified

- 通过 `rtk flutter analyze`，全量静态分析无 issue。
- 通过 `rtk flutter test test/task_folder_use_cases_test.dart`，9 项通过（含新增「按各自源名重渲染」用例）。

## 2026-06-25｜v1.2.1｜No Release

收口更新提示体验和媒体处理稳定性：更新入口从全量日志弹窗改为 L1 状态胶囊、L2 轻量通知弹窗和 L3 完整版本日志页；FFprobe / FFmpeg 执行链路增加超时、卡死和硬件编码会话失效保护。

### Added

- 新增 `UpdateNoticeDialog`：以 380px 级轻量弹窗展示新版本摘要、下载状态、安装动作和完整日志入口，mandatory 更新隐藏「下次再说」并禁止点击遮罩关闭。
- 新增更新 snooze 持久化端口和本地实现：同版本点击「下次再说」后，后续自动检查只显示工作台顶部入口，不再自动弹窗；新版本发布后 snooze 自动失效。
- 新增 Flutter `integration_test` 基础设施和 `integration_test/app_smoke_test.dart`：使用内存 Drift 数据库启动真实 `FrameLeanApp` Widget 树，覆盖应用启动 / 设置路由、文件导入自动建夹、通知中心持久化和手动更新入口等桌面集成烟测。
- 新增 FFmpeg 进程 stall 检测：长时间无 stdout / stderr 活动时强制终止进程并返回无响应失败，避免任务永久占用执行位。
- 新增硬件编码器会话失效自动恢复：VideoToolbox / NVENC / QSV / AMF 出现典型 external library 错误时，当前 step 清理残留输出后自动重试一次。

### Changed

- 工作台顶部更新入口由 32px 图标改为状态胶囊，按 `新版本`、`下载中`、`已暂停`、`已就绪`、`更新失败` 展示版本或进度。
- 新增 `appRuntimeEffectsEnabledProvider` 测试边界：生产默认开启系统快捷键、窗口 / 托盘监听、启动清理和更新自动检查；集成测试可关闭这些运行期副作用。
- 跨层共享常量下沉到 `domain/constants.dart` 和 `application/constants.dart`，`app/constants.dart` 只保留 app / UI 侧入口并 re-export 低层常量，避免低层反向依赖 app barrel。
- 设置页手动检查发现新版本后弹出 L2 更新通知，不再直接进入完整版本日志页；设置页移除独立「版本日志」按钮。
- 通知中心当前更新通知点击打开 L2 更新通知；历史版本通知直接进入 L3 完整版本日志页。
- FFprobe 分析从 `Process.run().timeout()` 改为 `Process.start`，超时后主动 kill 子进程并回收输出流。
- 任务失败通知改为展示友好失败原因和建议，原始 FFmpeg stderr 继续保留在任务日志中。
- macOS Sparkle xcconfig 注释改为当前默认手动 DMG 更新路线；Sparkle feed 和公钥只在显式启用 Sparkle appcast 路线时填写。

### Fixed

- 修复通知中心历史版本在缺少版本号时进入 `/settings/release-notes&from=workbench` 的 URL 拼接错误。
- 修复更新失败哨兵文件检查在无 `path_provider` 插件环境下抛出未处理异常的问题，保持启动检查 best-effort。
- 修复 `test/widget_test.dart` 测试适配器未使用可选参数和 `tool/sign_windows_update.dart` 空值 map 写法导致的全量 analyze issue。
- 修复 `architecture_dependencies_test.dart` 报出的 domain / application / infrastructure 反向导入 `app/library.dart` 问题，恢复 Clean Architecture 依赖护栏。
- 修复 FFprobe 超时后底层子进程仍可能在后台存活的问题。
- 修复 FFmpeg 进程挂死时队列一直停留在 `running` 并阻塞后续任务的问题。
- 修复任务失败通知可能直接暴露 exit code、硬件编码器 stderr 或内部转换失败细节的问题。

### Verified

- 通过 `rtk dart format` 覆盖本次触达的 Dart 文件。
- 通过 `rtk flutter test integration_test/app_smoke_test.dart`，4 个桌面集成烟测通过；macOS Debug app 构建阶段仅提示本地未放置 Universal FFmpeg / QMC 运行时。
- 通过 `rtk flutter test test/app_update_provider_test.dart`，更新自动检查、snooze、下载、安装 helper 和 Sparkle 策略测试共 9 个通过。
- 通过 `rtk flutter test test/architecture_dependencies_test.dart`，架构依赖护栏测试通过。
- 通过 `rtk flutter analyze`，全量静态分析无 issue。
- 通过 `rtk flutter test --file-reporter=json:/private/tmp/framelean_flutter_test_final.json`，全量 Flutter 测试 375 项通过。
- 通过 `rtk git diff --check`。

## 2026-06-23｜v1.2.1｜No Release

实施 library barrel 导入架构治理，重组工作台弹窗目录，并收口工作台图标常量。

### Added

- `lib/domain/library.dart`、`lib/application/library.dart`、`lib/infrastructure/library.dart`、`lib/app/library.dart`：分层 barrel 导出门面，按白名单封装公共 API。
- `lib/features/workbench/library.dart`、`lib/features/settings/library.dart`、`lib/features/notifications/library.dart`：功能模块 barrel 入口。
- `lib/app/presentation/widgets/confirm_dialog.dart`：通用二次确认弹窗模板，统一清除、重启、导入失败等确认弹窗样式。
- `lib/features/workbench/workbench_icons.dart`：工作台图标常量集中管理，包含 MediaKind / TaskStatus / 右键菜单扩展和散落 Icons 常量。
- `lib/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_state.dart`：任务配置弹窗状态管理。
- `lib/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_template.dart`：任务配置弹窗布局模板。
- `docs/decisions/260623-library-barrel-import-architecture.md`：barrel 导入架构决策文档。

### Changed

- 165 个源文件跨层导入从直达文件改写为经 `library.dart` barrel 导入（789 处改写）。
- `analysis_options.yaml` 启用 `always_use_package_imports: true`，永久禁止相对路径导入。
- 工作台弹窗从平铺 `dialogs/` 重组为 `dialogs/config/`、`dialogs/confirm/`、`dialogs/task/` 三个子目录。
- `media_kind_icons.dart` 合并到 `workbench_icons.dart`，删除 `presentation_mappers/` 目录。
- `workbench_dialog_widgets.dart` 拆解为 `ConfirmDialog`（共享组件）和各弹窗内联辅助方法。

### Verified

- `flutter analyze lib/` 零 warning。
- `flutter test` 通过 357 个；失败 12 个集中在 `app_update_provider_test.dart`（预存超时 + provider dispose 稳定性问题，barrel 改写无关）。
- 架构依赖测试失败 4 处为预存依赖方向违规（domain/infrastructure → app），barrel 聚合后更集中可见，属于 ADR 260614 治理范围。

---

## 2026-06-22｜v1.2.1｜No Release

移除应用内卸载入口和随包自卸载脚本，避免 Windows 端卸载功能异常影响用户体验。

### Removed

- 移除设置页"关于"区域的"卸载应用"按钮（原仅 Windows 显示），macOS 和 Windows 均不再提供应用内卸载入口。
- 删除 `AppUninstaller` 服务接口、`WindowsCleanAppUninstaller`、`NoopAppUninstaller` 实现及两个卸载 use case。
- 删除随包脚本 `installer/macos/FrameLean-Clean-Uninstall.command` 和 `installer/windows/FrameLean-Clean-Uninstall.ps1`。
- 移除 Windows 安装器 `[UninstallRun]` 自卸载钩子。

### Changed

- 更新 `docs/develop/architecture.md`、`docs/develop/test-plan.md`、`docs/releases/v1.2.1/self-hosted-update-client.md` 中的卸载相关描述。

---

## 2026-06-21｜v1.2.1｜No Release

修复 macOS 手动 DMG 更新流程在重启后重复提示下载的问题，并为 macOS DMG 增加自定义品牌化背景。

### Changed

- macOS DMG 构建增加自定义品牌化背景和布局：使用 FrameLean 浅色主题色（`#1D48E6` primary、`#F5F7FB` surfaceCanvas），DMG 打开后显示品牌色箭头、引导文字和 Applications 快捷方式，改善首次安装体验。

### Fixed

- 修复 `checkForUpdate` 在已有有效 DMG 包时仍显示”下载 DMG”的问题：现在检查更新发现新版本后，会先扫描下载目录是否存在对应版本且 SHA-256 / Ed25519 校验通过的包，存在则直接标记为已下载并显示”打开 DMG”。

## 2026-06-20｜v1.2.1｜No Release

今天继续收口 v1.2.1 桌面体验：输出运行时保护、任务 / 任务夹输出位置、现代视频容器矩阵、通知策略、快捷键系统和关闭到后台行为完成第一轮实现，并同步 FFmpeg 法律资料、macOS CocoaPods 发布链和 v1.2.1 release 文档。

### Added

- 新增隐藏 partial 输出保护：FFmpeg 先写入同目录隐藏临时文件，成功后原子发布到最终路径；运行中检测到 partial 连续消失会立即终止任务并提示临时输出被删除或移动。
- 新增应用启动 interrupted output 清理：异常退出后清理遗留 `.framelean-*.partial*`，并把仍处于运行 / 暂停态的任务标记为失败。
- 新增 `OutputLocationMode`，任务夹主区域和单任务高级设置都可选择“使用系统设置 / 源文件旁 / 自定义目录”，系统模式在执行时读取最新应用设置。
- 新增视频输出兼容矩阵：MP4、MOV、MKV、WebM、AVI 容器分别限制可用编码，AVI 定位为传统兼容格式，仅支持 MPEG-4 Part 2 和 MJPEG。
- 新增 VP9、AV1、ProRes、MPEG-4 Part 2、MJPEG 编码规划，以及 WebM / AVI 输出命令构建、能力检测和发布检查。
- 新增通知策略设置，可按事件选择“通知 / 临时通知 / 不通知”；普通交互和保存成功默认临时通知，任务结果、更新和重要失败默认持久通知。
- 新增快捷键系统与设置页重映射：Esc 返回 / 关闭顶层界面，F 添加文件或文件夹，Space 开始 / 暂停，主修饰键 + `,` 打开设置，主修饰键 + Shift + N 打开通知中心。
- 新增窗口关闭行为设置：默认关闭到后台，Windows 使用托盘恢复 / 退出，macOS 通过 Dock 重新打开窗口；显式退出时会确认运行任务并清理 partial 输出。
- 新增托管更新配置快照：macOS 支持 MDM / `/Library` 托管配置，Windows 支持 HKLM policy / `%ProgramData%` 托管配置，用户可写配置会被忽略。
- 新增 Windows 更新包 Ed25519 强制验签、严格断点恢复、重启前任务清理和 updater helper 安装后 build 确认。
- 新增 macOS Sparkle 2 更新桥接、重启前 Flutter 准备回调、Sparkle appcast 服务端接口、Admin Web 元数据导入和统一签名元数据生成。

### Changed

- FFmpeg 命令规划支持把执行输出路径替换为 partial 路径，同时保留任务最终输出路径；发布前会再次规避外部重名，避免覆盖用户文件。
- 视频格式转换继续优先安全流复制；不兼容时按目标容器自动选择保真转码参数，透明视频仍强制 MOV + ProRes 4444，不提供 AVI。
- 压缩配置中“推荐方案选项 / 自定义目标体积”切换改为 240ms 尺寸交叉动画，降低弹窗高度跳变。
- 任务夹设置顶部摘要右侧图标区改为受约束拉伸，跟随摘要高度对齐。
- 快捷键注册改为基于 `hotkey_manager` 的应用内热键，不再依赖页面焦点树；快捷键录入继续复用应用弹窗风格。
- 工作台左下角添加入口改为统一批次导入；macOS 通过原生选择器支持同一对话框多选文件和文件夹，Windows 保留文件多选和拖拽文件夹能力。
- macOS 桌面插件集成改为保留 CocoaPods `Podfile` / `Podfile.lock` 和 Runner workspace Pods 引用，用于窗口管理和托盘插件。
- Windows 自托管自动更新平台改为 `windows-installer`，`windows-x64` ZIP 调整为手动下载 / 后台留存包。
- FFmpeg 许可证、源码获取、第三方声明和内置运行时说明补充 libvpx、SVT-AV1、WebM、AVI、MPEG-4 Part 2、MJPEG、VP9、AV1 能力。
- 设置页关于分区动作区改为“更新 / 维护”两组，除检查更新外统一使用中性描边按钮，降低按钮颜色噪音。
- macOS / Windows GitHub Actions 发布打包改为显式注入更新服务地址；Windows 继续强制 Ed25519 签名配置，macOS Sparkle 配置仅在启用 Sparkle 路线时需要，缺少必要 GitHub Variables / Secrets 时直接失败。
- macOS 默认更新路线从 Sparkle 自动更新改为 JSON latest / ticket 检查、展示版本日志、下载 DMG 到用户下载目录并打开 DMG 所在位置；Sparkle appcast 仅作为未来可选签名路线保留。
- 服务端和 Admin Web 放开 macOS DMG 的 Sparkle 签名必填限制；Windows 安装器 Ed25519 签名仍为发布必填。
- `framelean-delivery` 和 `framelean-release` skills 增加打包新鲜度检查，要求交付和 release 文档生成前核对脚本、Action、YAML、签名和更新元数据链路。

### Fixed

- 修复 macOS 本地打包在 `macos-x64` 被误放 arm64 FFmpeg 时只报告模糊
  Universal runtime 错误的问题；现在会打印全部切片架构并明确引导使用
  `Build macOS Universal` Action 生成单一 Universal 2 DMG。
- 修复用户在任务运行中删除正在写入的目标文件时，进度仍继续跑到结尾才报错的问题；现在任务会在 partial 丢失后尽快失败并清理状态。
- 修复旧任务空输出目录语义不清的问题：旧空路径迁移为“源文件旁”，新任务默认使用系统设置。
- 修复任务结果、设置保存和普通交互通知无法区分持久 / 临时投递的问题。
- 修复任务设置和通知设置中的下拉框高度过矮、通知投递方式未垂直居中，以及快捷键录入时 Esc 误退出整个设置页的问题。
- 修复设置页分区动作被表单布局遗漏导致保存 / 取消按钮不可见的问题。
- 修复图片 fallback 结果在无 preflight 兼容路径下没有清理无效输出文件的问题。
- 修复 macOS release 脚本、CI 和文档仍按 v1.2.0 SwiftPM-only 口径描述的问题，当前统一为 CocoaPods 插件集成。
- 修复 Windows 彻底卸载脚本在 UAC 后可能清理到管理员用户目录的问题，提权前会解析原用户数据、临时目录、快捷方式和用户注册表根并传给 elevated 脚本。

### Verified

- 通过 `rtk dart format lib test tool`。
- 通过 `rtk flutter analyze`。
- 通过 `rtk flutter test test/app_update_provider_test.dart test/local_app_update_package_downloader_test.dart`。
- 通过 `rtk flutter test test/app_settings_page_test.dart`。
- 通过 `rtk flutter test --concurrency=1 test/app_notification_manager_test.dart test/app_settings_page_test.dart test/app_settings_save_coordinator_test.dart test/drift_app_settings_repository_test.dart test/output_preflight_service_test.dart test/ffmpeg_command_builder_test.dart test/ffmpeg_task_queue_runner_test.dart test/media_task_use_case_helpers_test.dart test/media_task_notifier_test.dart test/widget_test.dart test/workbench_bottom_bar_test.dart`，共 205 项定向回归。
- 通过 `flutter test`，共 358 项测试。
- 通过 `cd server/admin-web && npm run build`。
- 通过 `cd server && rtk mvn test -Dtest=ReleaseServiceTest,UpdateServiceTest`。
- 通过 `cd server && mvn test`，共 14 项测试通过，2 项 Testcontainers 集成测试因本机无 Docker 跳过。
- 通过 `rtk bash -n scripts/build/build_ffmpeg_macos_arch.sh`、`rtk bash -n scripts/build/build_ffmpeg_macos_universal.sh` 和 `rtk bash -n scripts/release/build_dmg_macos.sh`。
- 通过 `rtk git diff --check`。
- 通过 Ruby YAML 解析校验 `.github/workflows/build-macos.yml` 和 `.github/workflows/build-windows.yml`。
- 通过 Ruby YAML frontmatter 校验 `framelean-delivery` 和 `framelean-release` skills；`quick_validate.py` 因本机缺少 `PyYAML` 未运行。

## 2026-06-21｜v1.2.1｜No Release

今天改进版本号与构建号管理链路：构建号由手动硬编码改为 pubspec.yaml 自动生成，并在 .update.json 制品元数据中携带；服务端去掉脆弱的 MAX()+1 计数器，构建号改为 Admin 必填或从制品识别后填入。

### Added

- 新增 `tool/generate_build_info.dart`：从 `pubspec.yaml` 读取 `version: X.Y.Z+N` 并自动生成 `lib/application/services/framelean_build_info.dart`，构建脚本在 Flutter build 前自动执行，无需再手动同步两处版本号。
- macOS / Windows `.update.json` 制品元数据新增加 `version` 和 `buildNumber` 字段，由构建脚本从 `pubspec.yaml` 提取写入。
- Admin Web 新建版本草稿表单新增加“构建号”输入框（可留空），草稿详情页上传制品元数据后自动识别并对比构建号：
  - 构建号未设置时：蓝色提示 +“使用此构建号”按钮。
  - 与登记不一致时：黄色警告 +“改用识别结果”按钮。
  - 一致时：绿色“已核对”提示。
- 新增 `PATCH /api/v1/admin/releases/{version}/build-number` 接口，允许在草稿阶段修改构建号。
- 新增 `UpdateBuildNumberRequest` DTO 和 `ReleaseService.updateBuildNumber()` 方法。

### Changed

- `framelean_build_info.dart` 现在是自动生成文件，新增 `AUTO-GENERATED — DO NOT EDIT` 头注释。
- 服务端 `build_number` 来源从 `SELECT MAX(build_number) + 1` 计数器改为 Admin 显式传入；`ReleaseMapper.nextBuildNumber()` 已移除。
- `CreateReleaseRequest.buildNumber` 从 `Int?` 改为 `Int`，默认值 `0`（留空表示未设置）。

### Removed

- 移除 `ReleaseMapper.nextBuildNumber()` 方法和对应的 `MAX()+1` SQL 查询。

## 2026-06-19｜v1.2.1｜No Release

今天收口工作台任务夹拖拽、任务夹交互和受控并行队列，并重构执行作用域、批次导入分组、媒体处理意图和任务夹配置摘要。

### Added

- 新增全应用 `FrameLeanReorderableListView`，支持拖拽更新、三种 gap 策略、排序 / 外部接收 / 取消 drop、跨轴拖动和外部接收代理装饰。
- 任务夹内任务可通过拖拽柄移到面板外遮罩，释放后在落点缩小淡出并移回总列表。
- 新增受控并行执行：设置页可选择 1 到 3 个最大并行任务数，队列通过资源守卫按 CPU、内存和任务类型决定实际执行位。
- 新增任务和任务夹项目风格右键菜单；任务可通过“添加到任务夹”二级菜单加入同媒体类型任务夹，任务夹可右键重命名。
- 图片任务详情新增无损压缩开关；开启后仅提供 PNG、WebP、TIFF，WebP 使用 lossless 模式，TIFF 使用 Deflate，并隐藏有损质量滑杆。
- 导入入口新增文件夹选择和拖拽文件夹扫描；扫描深度默认 2 层并可在设置页调整，每种媒体独立达到 2 个时才创建对应任务夹。
- 任务详情新增“压缩 / 格式转换”意图切换和默认收起的高级设置，支持线程限制、视频两遍压缩模式及多音频流选择。

### Changed

- 任务详情和任务夹设置改用 Flutter 原生 Cupertino 滑动分段控件与复选框选项，并固定顶部标题栏和底部操作区；中间配置使用无回弹滚动和独立滚动条安全槽。
- 工作台顶层拖拽保留官方 ReorderableList 的拖拽代理、自动滚动和 gap 动画，同时增加同类型任务夹整行冻结、返回任务夹时 gap 复位和 drop 消费钩子。
- 同类型任务夹中部释放仍走入夹；上下 16px 边缘释放、普通任务和跨类型任务夹仍走排序路径，跨类型任务夹保持禁用视觉且不显示拒绝提示。
- 顶层排序采用乐观视觉顺序衔接异步 Drift 持久化；提交成功后由仓储结果接管，失败时回滚，避免 drop 动画结束后列表项短暂返回旧位置。
- 夹内排序同样使用乐观视觉顺序；移出持久化失败时恢复任务行，面板标题区和内部空白区释放按取消处理。
- 任务夹内容浮层改为从左侧滑入，与通知中心右侧浮层保持对称动画；多选创建任务夹入口改为应用左侧批量操作条。
- 新任务和新任务夹插入到未完成项之后、已完成项之前；任务夹默认名称改为媒体类型加序号。
- 队列改为工作台、任务夹和单任务三种执行语义；满执行位时单任务抢占最早运行者，被抢占任务按 FIFO 优先恢复，底部暂停后单开任务不会重启旧队列。
- 格式转换主区域只保留目标格式，图片、音频和视频由后台使用保真策略；压缩模式继续显示适用的质量、码率和尺寸选项。
- 任务夹设置顶部改为任务数、总源体积、格式分布和总时长 / 尺寸分布，不再借用首个任务信息。
- 已完成压缩任务的列表摘要改为“源体积 - 输出体积 · 压缩比例”，格式转换任务改为“源格式 - 目标格式”，不再显示压缩百分比。

### Fixed

- 修复文件选择、文件拖入和文件夹扫描的自动建夹规则不一致，以及同类型单个媒体被错误放入任务夹的问题。
- 修复任务夹“保持原格式”配置直接复用首个格式的问题，现按每个源文件独立解析。
- 修复音频压缩可能把不小于源文件的输出标记为成功的问题。

- 移出任务的 `sortOrder` 现在同时参考普通任务和任务夹，确保位于整个顶层混排列表尾部。
- 移除任务配置上下文和任务行视觉选中态的耦合；普通和多选模式均不再显示蓝色任务行边框。
- 修正左侧任务夹内容浮层打开时缺少滑入动画的问题。
- 修复总列表任务夹在运行结束后仍保留聚合进度底色的问题，非运行状态恢复普通卡片背景。

### Verified

- 通过本次触达的 23 个 Dart 文件 `rtk dart format --set-exit-if-changed` 检查。
- 通过 `rtk flutter analyze`。
- 通过队列、导入、命令构建、任务夹和 Widget 定向回归，共 152 项测试。
- 通过 `rtk flutter test`，共 346 项测试。

## 2026-06-18｜v1.2.1｜No Release

今天收口自托管更新、Admin 版本制品管理、媒体处理可靠性和任务夹重构近期改动：优化 Admin Web 版本制品页布局，补齐 v1.2.1 自托管更新客户端 / 服务端 / Admin Web 版本事实文档，新增客户端更新状态机和 server 更新服务核心测试，并支持在 Admin Web 删除登记版本时同步清理 COS 对象和数据库依赖记录。主项目同步修复图片压缩越压越大、透明视频错误输出、输出路径启动后才失败和批量任务缺少容器的问题。

### Added

- 新增 `docs/releases/v1.2.1/` 版本事实文档，记录自托管更新客户端、server 更新服务和 Admin Web 版本管理边界。
- 新增 `test/app_update_provider_test.dart`，覆盖自动检查更新、下载完成和 Windows updater helper 启动状态流。
- 新增 server `UpdateServiceTest`，覆盖按平台可见包过滤 latest、下载 ticket resolve 签发 COS URL、下载审计事件和 IP 屏蔽审计。
- 新增 Admin 删除登记版本入口：删除 release 登记时会同步删除版本日志和 package 对应的 COS 对象，并清理 download events、packages、requirements 和 release 记录。
- 新增图片压缩结果验收和 fallback 计划：首轮按源格式尝试，未变小时清理候选并改用 WebP / JPG 重试；第二轮仍无效时任务失败并提示原因。
- 新增透明视频保留策略标签和 MOV / ProRes 4444 输出策略，FFmpeg 缺少 `prores_ks` 时在命令构造阶段失败。
- 新增输出 preflight 服务，FFmpeg 启动前创建输出目录、规避同源覆盖 / 重名、检查可写性，并给任务打 `目录已创建` / `输出已改名` 标签。
- 新增任务夹领域模型、Drift `task_folders` 表、任务 `folderId` / `folderSortOrder` / `policyTags` 字段和任务夹仓储 / use case。
- 新增工作台任务夹列表项和左侧夹内任务浮层，批量导入会按媒体类型自动创建任务夹。
- 新增任务夹批量工作流：任务夹设置批量应用、多选 FAB 按媒体类型建夹、未入夹任务通过拖拽柄拖入同类型任务夹、跨类型任务夹禁用视觉、任务夹尾部批量开始 / 暂停 / 重试 / 重链入口。
- 新增通知中心任务结果详情：任务成功记录源 / 输出体积、压缩比例、保存路径和耗时，任务失败记录明确原因和建议；通知中心动作改为正文下方文字按钮组。
- 新增工作台总列表任务 / 任务夹混排排序、夹内任务排序、普通模式框选进入多选、Command / Control 框选反选和分析中点击的临时交互通知。
- 新增任务项尾部“打开完成文件位置”入口、任务夹日志聚合弹窗、空任务夹自动清理和清空任务时同步清空任务夹。

### Changed

- 优化 Admin Web 版本制品页信息结构，将版本索引、基础信息、制品列表、版本日志和发布操作重新整理为更清晰的工作区。
- server README 同步记录 `DELETE /api/v1/admin/releases/{v}` 删除登记版本接口。
- 图片保持源格式时，命令规划改为优先解析源图片 codec / 扩展名作为首轮输出格式，再按透明能力选择 fallback。
- 工作台总列表改为显示任务夹和未入夹任务，夹内任务默认不在总列表重复出现。
- 任务夹主体点击打开夹级配置弹窗，尾部查看按钮才打开左侧夹内任务浮层；浮层内任务复用普通任务行样式和操作按钮。
- 移除任务完成弹窗链路和设置页“任务完成后以弹窗的形式提示”选项；完成后只保留提示音、通知中心记录和任务项完成文件入口。
- 队列启动顺序改为按总列表从上到下展开任务夹，夹内按 `folderSortOrder` 执行；单任务开始仍作为插队入口，插队完成后继续按最新顺序推进。
- 任务夹尾部去掉重链按钮，副标题追加源文件丢失计数；总列表多选时任务夹拖拽手柄置灰但不变成复选框。
- Windows 默认启动窗口宽度收敛到当前最小宽度；Inno 安装器增加可选桌面快捷方式。

### Fixed

- 修复图片压缩在任意质量百分比下可能输出更大文件但仍被标记成功的问题。
- 修复透明视频被常规 H.264 / yuv420p 策略破坏 alpha 通道的问题。
- 修复任务行右侧开始 / 暂停 / 重试 / 移除按钮点击时同时触发任务配置弹窗的问题。
- 修复版本日志页返回按钮总是跳到设置页的问题，优先按路由栈返回上一页。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test`，共 299 项测试。
- 通过 `cd server && mvn test`，12 项运行，2 项在无 Docker 环境下跳过。
- 通过 `cd server/admin-web && npm run build`；仍保留 Vite 大 chunk 提示。
- 通过主项目和 server 的 `git diff --check`。
- 通过 `flutter test test/ffmpeg_command_builder_test.dart`，覆盖图片 fallback 和透明 ProRes 4444 命令。
- 通过 `flutter test test/ffmpeg_task_queue_runner_test.dart`，覆盖图片首轮无效进入 fallback、fallback 仍无效时失败和清理输出。
- 通过 `flutter test test/output_preflight_service_test.dart`，覆盖目录创建、重名改名、同源保护和 FFmpeg args 回写。
- 通过 `flutter test test/media_task_policy_tags_test.dart`，覆盖重试、换源和重分析后的策略标签刷新。
- 通过 `flutter test test/drift_media_task_repository_test.dart`，覆盖任务夹持久化和任务 folder / policy tags 往返。
- 通过 `flutter test test/task_folder_use_cases_test.dart`，覆盖任务夹批量配置、终态任务批量重试和夹内下一项启动。
- 通过 `flutter test test/widget_test.dart`，覆盖任务夹总列表、夹级设置、侧边栏夹内任务操作、多选 FAB、拖入任务夹和任务行按钮误触边界。
- 通过 `flutter test test/app_notification_manager_test.dart test/app_settings_page_test.dart test/drift_app_settings_repository_test.dart test/media_task_execution_use_cases_test.dart test/task_folder_use_cases_test.dart test/reorder_workbench_items_use_case_test.dart test/ffmpeg_task_queue_runner_test.dart test/notification_center_panel_test.dart test/widget_test.dart`，覆盖通知、设置、清空任务夹、任务夹排序、队列展开和通知中心布局。

## 2026-06-17｜v1.2.1｜No Release

今天为 server v1.0.0 增加内置 Admin 管理端第一版：`/web` 由 Spring Boot 直接托管 React + Ant Design 后台，支持下载统计、检查更新审计、下载 IP 记录、IP 屏蔽，以及版本成果物管理。管理端采用唯一管理员主密码机制，主密码只在浏览器本地用于解密私钥并签名登录 challenge，服务端不保存密码或密码哈希。

### Added

- 新增 `server/admin-web` React + Vite + Ant Design 管理端，使用深蓝侧边栏、白色内容区、灰色分割线和蓝色主色。
- 新增 Admin Web 首次初始化、主密码登录、HttpOnly Cookie 会话和 CSRF 校验。
- 新增 `admin_auth_config`、`release_artifact_requirements`、`update_check_events` 和 `ip_block_rules` 数据表。
- 新增 Admin dashboard、检查更新审计、下载审计、IP 屏蔽和版本详情 / 必填成果物接口。
- 新增 `/web` 静态入口，Dockerfile 多阶段构建会把 Admin Web dist 打包进后端 jar。
- 新增 Admin 版本草稿创建流程：一次拖拽上传 Windows x64、macOS Universal 和版本日志 md，可选上传 Windows 直装版留存包，上传完成后进入草稿确认页。
- 新增 COS 分片上传管理接口，Admin Web 通过服务端预签名 URL 支持大文件断点续传。
- 新增 `release_packages.client_visible` 和 `releases.notes_object_key`，区分客户端更新成果物、官网留存成果物和日志 md 的 COS 对象。

### Changed

- 管理接口保留 `X-Api-Key` 脚本鉴权，同时支持 Admin Web Cookie 会话。
- 检查更新和下载 ticket 创建统一读取反代后的真实 IP，并在 IP 被屏蔽时拒绝继续。
- 发布前校验扩展为按版本配置的必填平台成果物逐项检查，Windows 直装版成果物在服务端归一化为可选。
- Admin 版本创建不再填写 Build，服务端在 `server v1.0.0` / 后端 `v1` 线内自动递增内部 build number。
- Admin 版本成果物从“先建版本、再单独上传包”改为“创建草稿、草稿确认、点击发行”。
- 客户端更新检查和下载 ticket 接口切换到 `/api/v1/releases/latest` 与 `/api/v1/releases/download-ticket` 路径。
- 客户端更新接口只接受 `windows-x64` 和 `macos-universal2`；Windows 直装版仅上传留存，不会进入检查更新或下载 ticket。

### Fixed

- 修复 Admin Web 页面标题在浏览器顶部被裁切的问题，根节点、Header 和内容滚动区重新分离。
- 修复新建版本弹窗过长且无法上传成果物文件的问题，改为可滚动的四槽位拖拽上传表单。
- 修复新建版本时 Windows 直装版留存包被强制上传，导致无直装版时不能完成草稿创建和发行确认的问题。
- 修复 Admin Web 上传成果物时按文件名强制校验平台和架构，导致旧版 macOS 包无法进入草稿的问题；草稿基础信息改为展示包架构支持标签。

### Verified

- 通过 `cd server && mvn -DskipTests package`。
- 通过 `cd server && mvn test`；当前无 Docker 环境下 Testcontainers smoke test 自动跳过。
- 通过 `cd server/admin-web && npm run build`。
- `docker build -t framelean-backend-admin-web:test .` 未执行成功：本机 Docker daemon 未运行，无法连接 `/Users/leftzhou/.docker/run/docker.sock`。

## 2026-06-16｜v1.2.1｜No Release

今天接入自托管更新 v1.2.1 客户端主流程和 server v1.0.0 更新服务加固：设置页关于栏可以自动 / 手动检查更新并进入下载、暂停、继续和待重启状态，通知中心支持单版本更新通知和双动作，工作台顶部在存在更新时持续显示入口，版本日志页面和日志弹窗开始承接 Markdown 日志。服务端加入 Redis，用于下载票据、限流和 latest cache，并修复平台包过滤、发布前校验、测试依赖和 validation 400 返回。

### Added

- 新增客户端更新状态模型、更新服务抽象、HTTP 更新客户端、断点下载器、安装 ID 存储和 Windows updater helper launcher。
- 新增 `app_notifications.dedupe_key`，更新通知使用 `update:{platform}:{version}:{buildNumber}` 去重。
- 新增设置关于栏 `检查更新` / `现在更新` / 进度 / `重启更新` 固定尺寸按钮和 `版本日志` 入口。
- 新增工作台顶部持续更新入口、更新日志弹窗和 `/settings/release-notes` 版本日志页面。
- 服务端新增 Redis 依赖、Redis 限流、短期下载票据创建 / resolve 接口和版本日志列表接口。

### Changed

- 应用版本升级为 `1.2.1+5`，`FrameLeanBuildInfo` 同步为 `1.2.1` / build `5`。
- 更新检查最新版本查询改为按平台可用包过滤，避免无当前平台包的新 release 挡住旧可用版本。
- 服务端发布 release 前校验 notes、package、COS object key、size、sha256 和 signature。

### Fixed

- 修复服务端 `@ServiceConnection` 测试依赖缺失问题，补 `spring-boot-testcontainers`。
- 修复 Kotlin Spring final class 可能影响事务代理的问题，启用 Kotlin Spring all-open compiler plugin。
- 修复 validation / 参数错误落入通用 500 的问题。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `cd server && mvn -DskipTests package`。
- 通过 `cd server && mvn test`；当前无 Docker 环境下 Testcontainers smoke test 自动跳过。

## 2026-06-14｜v1.2.0｜Release

完成 v1.2.0 发布准备。本版本从 v1.1.5 起扩展视频、图片和音频统一处理能力，加入专有音频输入、完整设置页、通知中心、输出文件名模板、任务完成提示音、HDR / SDR 色彩处理，以及 macOS Universal 2 和 Windows 安装器发布链。本次收口同时完成 P0-P2 架构治理，并修复 v1.2.0 打包流水线与桌面体验校验问题。

### Added

- 新增图片 / 音频统一任务模型、分类型配置、FFprobe 分析和基础 FFmpeg 处理。
- 新增 NCM 本地解密和 QMC 外部适配器输入链路。
- 新增全屏应用设置、分区保存 / 取消、缓存清理和 Windows 清理卸载入口。
- 新增持久化通知中心、任务完成提示音和成果物文件夹动作。
- 新增输出文件名模板、媒体默认值、保持原始格式和元数据保留配置。
- 新增 HDR10 / HLG 转 SDR、受限保持 HDR 和 Dolby Vision 风险拦截。
- 新增 macOS Universal 2、Windows ZIP + Inno Setup 安装器发布链。
- 新增 Clean Architecture import 守卫测试。
- 输出文件名模板新增 `{version}` 变量，首次处理渲染为 `v1`，同源同类型同目的重复导入会递增为 `v2`、`v3`。

### Changed

- Riverpod provider 从 `infrastructure/providers` 迁移到 `app/providers` composition root。
- 输出配置刷新既有任务改由 application use case 执行，feature notifier 不再被 infrastructure 反向调用。
- 文件选择、外链打开、文件管理器定位和主题缓存改为 application 抽象，由 infrastructure 提供桌面实现。
- 跨 settings、notifications、workbench 复用的主题扩展、领域标签、表单控件、布局常量和百分比滑杆迁入 `app`。
- 应用版本升级为 `1.2.0+4`，发布产物统一使用 `FrameLean-v1.2.0` 前缀。
- 任务完成提示音改用 `audioplayers` 直接播放 Flutter asset，Windows 不再启动 PowerShell。
- 输出文件路径冲突自动后缀从 `-1` / `-2` 调整为 `（1）` / `（2）`。
- 默认设置收敛为跟随系统主题、清脆完成提示音、三类媒体默认保持源格式并保留元数据、视频默认微信发送、图片质量 80%、默认导出到源文件旁和 `{source}-{action}` 文件名模板。
- 桌面字体缩放允许 4K / 大窗口环境在上限内放大，Windows 启动窗口按主屏工作区和 DPI 自适应放大，不再固定压回基础尺寸。
- Windows Actions 分别上传便携 ZIP 和 `setup.exe` 安装器 artifact，不再把两个发布包混进同一个 artifact zip。

### Fixed

- 修复 Drift 新增列迁移可能重复添加列的问题。
- 修复任务排序持久化、主题缓存一致性、macOS 首次点击、重复操作和 QMC 探测问题。
- 修复非视频任务详情、保持原始格式 / 分辨率、输出命名和 HDR 色彩参数边界。
- 修复 macOS Universal 2 CI 构建 zimg 时缺少 `aclocal` 的原生依赖声明，以及 Windows 打包脚本因截断 `ffprobe.exe -version` 管道而误判运行时版本校验失败的问题。
- 修复 macOS Universal 合并脚本在 GitHub Actions artifact 下载后多一层目录、以及 artifact zip 丢失可执行权限时找不到或无法执行 `ffmpeg` / `ffprobe` 或 QMC 适配器的问题。
- 修复 macOS Universal DMG 构建仍保留 CocoaPods 集成导致 Flutter SwiftPM 路径继续触发 `pod install`，并在 CI Ruby ASCII-8BIT locale 下失败的问题；macOS 工程改为只保留 Swift Package Manager 集成，发布脚本强制 UTF-8 并拦截 CocoaPods 残留。
- 修复输出文件名模板包含 `{version}` 时重复处理仍输出 `filename-v1（1）` 的问题；现在已有 `v1` 时优先输出 `v2` / `v3`。
- 修复输出配置中“保存到原文件旁”的错字，统一为“保存到源文件旁”。
- 移除已无引用的旧设置弹窗组件和未使用的 `cupertino_icons` 依赖。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test`，共 267 项测试。
- 通过 `flutter test test/architecture_dependencies_test.dart`。
- 通过 P0-P2 触达模块 76 项回归测试。
- 通过 release workflow / 打包脚本语法检查。
- 通过 `git diff --check`。
- macOS DMG 已本地构建并通过 Universal 2 校验（7 个 Mach-O 全部 arm64 + x86_64）；签名、公证和 Windows 安装器验收仍需在发布环境完成。
- 图片和音频端到端验收已通过 macOS 和 Windows。

## 2026-06-13｜v1.2.0｜No Release

今天接入任务完成提示音：设置页可以选择内置短提示音，设置会持久化到本地数据库，任务完成通知发出时会按当前设置播放对应音效。同时完成视频压缩底层色彩修复第一阶段：扩展 FFprobe 色彩 / HDR / Dolby Vision 分析字段，HDR10 / HLG 通过 `zscale + tonemap` 转 SDR，SDR 不再统一硬贴 BT.709，并将硬件编码器质量参数从 CRF 数值中拆开映射。媒体任务配置也同步完善“保持原始”、默认值和元数据语义：设置页默认值只影响后续导入任务，任务详情里显示真实源格式加“保持原始”提示，不向底层格式枚举写入 `source` 伪值。

### Added

- 新增 `assets/sounds/` 内置任务完成音效资源声明，并在设置页“完成音频设置”中提供“不通知”和 5 个命名提示音选项。
- 新增 `settings.task_completion_sound` 持久化字段，保存任务完成提示音偏好。
- 新增桌面端任务完成音效播放服务：macOS 使用 `afplay`，Windows 使用系统 `SoundPlayer` 播放缓存到临时目录的内置 WAV。
- FFprobe 分析结果新增 chroma location、HDR10 Mastering Display、MaxCLL / MaxFALL、Dolby Vision Profile 和兼容 ID，并通过 Drift schema 19 迁移持久化这些字段。
- macOS FFmpeg 构建脚本新增 zimg / libzimg 静态构建和 `--enable-libzimg`，发布脚本新增 `zscale` / `tonemap` 滤镜能力校验。
- 新增 HDR / SDR 色彩命令构造、Dolby Vision Profile 5 拒绝处理、硬件质量映射和新分析字段持久化回归测试。
- 视频和音频任务配置新增元数据保留开关，默认保持既有行为；用户关闭后 FFmpeg 命令会显式剥离输出元数据。
- 应用设置新增任务完成后是否弹窗提示的即时生效选项；关闭弹窗后任务完成改为更长停留的临时通知，并提供打开输出文件夹入口。

### Changed

- HDR10 / HLG 视频压缩输出改为通过 `zscale + tonemap` 转 SDR BT.709，不再依赖 VideoToolbox `scale_vt` 做粗略转换。
- SDR 输出优先保留源文件 range、matrix、transfer 和 primaries；缺失时才按分辨率推断 BT.709 或 SMPTE 170M。
- VideoToolbox `q:v`、NVENC CQ、QSV global quality 和 AMF QP 改为独立质量映射，不再直接复用 CRF 数值。
- 图片 / 视频 / 音频默认输出格式在设置页改为独立行展示，保持源格式复选框开启时禁用下方固定格式选择；图片默认质量独立成行并复用任务详情质量滑杆。
- 任务详情弹窗移除单独的“保持源文件格式”开关行，格式下拉中的真实源格式选项直接显示 `（保持原始）` 提示，例如 `MOV（保持原始）`。
- HDR 源视频开启“保持 HDR”后自动切换到 HEVC 并禁用编码选择，关闭后恢复用户开启前的编码选项。
- HDR 源视频开启“保持 HDR”后自动切到推荐方案并默认选择清晰优先，禁用自定义目标体积，并在推荐预设中禁用微信发送和体积优先。
- 任务成功 / 失败通知标题改为直接表达事件结果；临时通知展示短摘要，通知中心展示更完整的文件名、路径或错误详情。
- FFmpeg 许可、源码分发、第三方声明、技术栈、数据模型和测试计划文档同步记录 zimg 与 HDR 转 SDR 边界。

### Fixed

- Dolby Vision Profile 5 或无 HDR10 兼容层的 Dolby Vision 首版会在命令构造阶段失败，避免输出变黑、偏紫或严重偏色。
- 修复保持 HDR 输出时把 `bt2020nc` 写入 `scale` 的 `out_color_matrix` 导致 FFmpeg 参数解析失败的问题。
- 修复 SDR BT.601 / SMPTE 170M 等源素材被统一写成 BT.709 metadata 的风险。
- 修复图片和音频任务列表项点击后读取视频专属配置导致任务详情弹窗打不开或抛错的问题。
- 修复 MOV 等源格式在任务详情格式下拉中未显示 `（保持原始）`，以及源分辨率选项同时出现普通值和保持原始值的重复展示问题。
- 修复输出文件名模板提示文本可选中但不能通过 Command / Control + C 复制的问题。
- 修复 `{source}-{encoder}` 这类模板在用户需要实际编码器信息时显示 `auto` 的语义偏差，输出命名现在按任务实际解析后的编码器后端生成。

### Verified

- 通过 `dart run build_runner build --delete-conflicting-outputs`。
- 通过本次触达 Dart 文件格式化。
- 通过 `flutter analyze`。
- 通过 `flutter test test/ffprobe_media_analyzer_test.dart test/ffmpeg_command_builder_test.dart test/drift_media_task_repository_test.dart`。
- 通过 `flutter test`，共 256 项测试。
- 通过 `bash -n scripts/build/build_ffmpeg_macos_arch.sh`、`bash -n scripts/build/build_ffmpeg_macos_universal.sh`、`bash -n scripts/release/build_dmg_macos.sh` 和 `git diff --check`。

## 2026-06-12｜v1.2.0｜No Release

今天闭环 Windows x64 安装器发布链，并将 macOS 发布目标扩展为 Universal
2：Windows 发布包同时生成便携 ZIP 和 Inno Setup 安装器，macOS 建立 Intel
x86_64 与 Apple Silicon arm64 双架构运行时构建、合并、全包验证和 CI
打包链。

### Added

- 新增 `scripts/README.md`，按第三方运行时构建和应用发布两类职责列出脚本，并明确 `build_windows.ps1` 是唯一 Windows 正式发布入口。
- GitHub Actions Windows 构建新增锁定 commit 的 `qmc-decrypt` 构建步骤，产物和上游许可证会进入发布目录。
- 新增 macOS FFmpeg / FFprobe 和 QMC 适配器按架构构建、Universal 合并脚本。
- 新增 `.app` 全量 Mach-O 架构扫描脚本，要求所有原生文件同时包含 x86_64 和 arm64。
- 新增 GitHub Actions macOS 双 runner 构建和单一 Universal DMG 发布流程。

### Changed

- 输出配置中的默认导出文件名从固定下拉项改为模板输入框，默认模板为 `{source}-{date}-{action}`，支持 `source`、`date`、`action`、`codec`、`encoder` 英文变量；`codec` 使用 `h264 / h265`，`encoder` 使用 `auto / x264 / x265 / videotoolbox / nvenc / qsv / amf`，数字之间输入的 `x / X` 会自动替换为 `×`，并兼容清理 `x{codec}` / `x{encoder}` 前缀避免生成 `xh264` 或 `xx264`；输入框右侧提供常用模板菜单，选择模板只替换当前输入内容，用户仍可继续自由编辑。
- 设置保存语义区分默认任务配置和输出配置：视频 / 图片 / 音频任务配置保存后作为后续导入默认值；输出配置保存后会立即刷新未开始、失败和已取消任务的输出目录与文件名，运行中任务保留当前执行快照并在重来时读取最新输出配置。
- 合并 `build_windows.ps1` 和 `build_windows_installer.ps1`；单一脚本默认一次 Flutter 构建同时生成 `FrameLean-v*-windows-x64.zip` 和 `FrameLean-v*-windows-x64-setup.exe`，并支持按需跳过其中一种产物。
- Windows 安装器固定为当前用户安装到 `%LOCALAPPDATA%\Programs\FrameLean`，不再提供管理员安装切换，为后续无 UAC 静默覆盖更新保持稳定权限边界。
- Windows Release 构建会从 Visual Studio x64 Redistributable 目录复制 `msvcp140.dll`、`vcruntime140.dll` 和 `vcruntime140_1.dll`，缺失时停止发布。
- Windows 发布与安装器校验统一接受 `framelean-qmc-adapter.exe` 或 `qmc-decrypt.exe`。
- Xcode Build Phase 和 DMG 脚本只消费 `macos-universal` 运行时。
- DMG 流程改为先显式构建并验证 app，再执行签名、公证和镜像生成。
- macOS 平台范围从 Apple Silicon 调整为 Intel 与 Apple Silicon 共用一个 Universal 2 DMG；Windows 继续只支持 x64。

### Verified

- 通过 GitHub Actions workflow YAML 解析和 `git diff --check`。
- 通过 `flutter analyze`。
- 通过 `flutter test`，共 226 项测试。
- 待 GitHub Actions `windows-2022` runner 完成真实 ZIP、安装器和干净 Windows 安装验证。
- 通过全部 macOS 构建与发布脚本的 Bash 语法检查。
- 通过 workflow YAML 结构检查和 `git diff --check`。
- 通过 `flutter analyze` 和全部 228 项 `flutter test`。
- 本机 Release app 主体构建成功，Runner、Flutter、App 和插件框架共 6 个 Mach-O 文件均通过 x86_64 / arm64 扫描。
- 使用合成架构切片跑通 FFmpeg / QMC Universal 合并脚本，并确认纯 arm64 文件会被发布校验拒绝。
- 真实双架构 FFmpeg/QMC 产物合并、完整 DMG 和 Intel 真机验收等待双架构 CI。

### Fixed

- 修复任务重命名后再次套用输出设置会把导出文件名误生成为重命名标题（例如 `1.mp4`）的问题；模板中的 `{source}` 现在始终来自源文件路径。

## 2026-06-11｜v1.2.0｜No Release

今天为通知中心接入打基础：将工作台右上角入口改为通知中心按钮，新增应用级持久化通知管理，并修复设置页分区保存 / 取消 / 离开页面的状态语义。

### Added

- 新增 `app_notifications` Drift 表和 `AppNotificationManager`，应用内提示会先写入本地通知历史，再由根级 `AppNotificationHost` 统一展示。
- 新增工作台右侧通知中心自制浮层，通过右上角通知按钮触发右向左滑入动画，支持遮罩 / `Esc` 关闭、未读角标、批量已读和清扫通知。
- 新增类型化任务通知和持久化任务载荷；任务完成后通知项提供成果物文件夹按钮，可复用系统文件管理器定位输出文件。
- 新增通知持久化和设置页分区保存回归测试，覆盖保存成功、保存失败、页面离开后异步保存继续完成、分区切换 / 取消 / 返回只回滚不自动保存。
- 新增 `AppNotificationHost` 回归测试，覆盖全局通知卡片在应用根层级展示时仍能正常使用 `Tooltip` / `Overlay`。
- 新增通知中心 Widget 回归测试，覆盖滑入动画、打开后已读、成果物动作、清扫、未读角标和键盘关闭。
- 应用设置新增“关闭通知角标”持久化开关，默认开启；关闭该选项后工作台恢复显示未读数量角标。

### Changed

- 工作台右上角“关于 FrameLean”按钮改为“通知中心”入口；关于内容只保留在设置页“关于”分区。
- 工作台和任务日志的临时提示改为通过应用通知管理器发出，为后续右侧通知中心读取统一历史做准备。
- FFmpeg 队列完成或失败后直接发布持久化任务通知，不再依赖工作台页面是否仍然可见。
- 通知模型新增 `general`、`settings`、`task` 类型扩展入口，后续更新通知可在不改通知中心主体的前提下新增类型和动作解析。
- 根级临时通知调整为中等密度的分层标题样式：右上角展示、状态图标带浅色底、关闭按钮固定在通知尾部，详情最多展示两行。
- 根级临时通知支持替换动画：新通知到达时先让当前通知退出，再显示最新通知；短时间连续通知只保留最后一条展示。
- 临时通知标题改为真实事件文案：设置保存按分区显示“应用设置已保存 / 输出配置已保存”等，任务通知将文件名提升到标题，例如“demo.mp4 处理失败”。
- 设置保存目标通过结构化枚举区分；视频 / 图片 / 音频默认配置只影响后续导入任务，输出配置保存后才刷新非运行状态任务。
- 通知中心打开期间暂停临时通知展示，避免两个右上角浮层重叠。
- 通知中心面板和通知项按设计稿收敛为白底、细边框、小圆角、内部状态线与紧凑两级文字；通知副标题保留结果信息并显示通知时间。
- 设置页保存成功 / 失败提示不再依赖设置页 `context`，保存事件进行中离开页面也会在完成后记录并展示通知。
- 设置页代码结构拆分为 `pages/app_settings_page.dart`、`sections/` 和 `widgets/`，分区与通用组件提升到 feature 根目录，入口文件只保留加载、依赖注入和主视图状态骨架。

### Fixed

- 修复工作台旧关于弹窗仍引用已删除 `assets/icons/github.png` 导致全量 widget 测试失败的问题。
- 修复根级通知提示放在 `MaterialApp.builder` 外层时缺少 `Overlay`，导致通知关闭按钮 `Tooltip` 抛出 `No Overlay widget found` 的问题。
- 修复通知历史默认只读取最近 50 条的问题；通知中心现在读取全部未归档通知，清扫操作使用持久化软归档。
- 修复设置页保存失败被页面吞掉后仍把本地基准更新为“已保存”的问题。
- 修复分区保存中返回按钮仍按旧 `saving` 状态判断、可能在保存中离开页面丢失提示的问题。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test test/app_notification_manager_test.dart test/drift_app_notification_repository_test.dart`。
- 通过 `flutter test test/app_settings_page_test.dart`。
- 通过 `flutter test test/widget_test.dart`。
- 通过 `flutter test`。

## 2026-06-09｜v1.1.5｜No Release

今天将应用设置从工作台弹窗迁移为全屏 `/settings` 路由页面，并按 v1.2.0 原型整理左侧设置导航、右侧配置内容和应用维护入口。

### Changed

- 应用设置入口改为全屏跳转页面，工作台设置按钮通过 GoRouter 进入 `/settings`，设置保存后返回工作台。
- 设置页面保留原型中的常规配置、任务设置、输入和输出分组，并继续复用现有设置实体、保存用例、路径控件和缓存清理 / Windows 卸载入口。
- 关于页底部图标接入 Gitee、GitHub、Gmail 和掘金真实链接，并复用工作台外链打开器。
- 将应用设置测试从弹窗测试调整为页面测试，覆盖侧边栏导航、主题、输出、编码器、视频 / 图片 / 音频默认值和关于页缓存清理。

### Fixed

- 修复 macOS Debug 窗口首次点击只激活窗口、按钮需要点两次才触发的问题；Runner 现在会让 FlutterView 以及 `desktop_drop` 注入的原生拖拽视图都接受 first mouse。
- 工作台打开页面、弹窗、文件选择器和任务动作入口增加一次性 in-flight guard，避免 debug 慢响应下连续点击叠出多个路由、弹窗或重复任务动作。

### Verified

- 通过 `flutter test test/app_settings_page_test.dart test/workbench_external_link_opener_test.dart`。
- 通过 `flutter test test/widget_test.dart test/workbench_bottom_bar_test.dart`。
- 通过 macOS Debug Runner `xcodebuild` 编译。
- 通过 `flutter analyze`。
- 通过 `flutter test`。

## 2026-06-08｜v1.1.5｜No Release

今天重构 FrameLean 文档信息架构和项目级 skills，将过程型功能文档、碎片问题日志和冗余阶段 skill 收敛为上下文、工作区、版本事实、决策、经验总结和轻量 workflow 路由。

### Added

- 新增根目录 `CONTEXT.md`，集中记录项目定位、当前版本、能力边界、架构边界、平台范围和文档入口。
- 新增 `docs/work/`，用 `active.md`、`backlog.md`、`decisions.md` 管理当前任务、候选任务和有效决策索引。
- 新增 `docs/releases/`，按 `v1.0.0`、`v1.1.0`、`v1.1.5` 记录版本形成的稳定事实设计。
- 新增 `docs/decisions/`，按 `YYMMDD-summary.md` 记录重要决策正文。
- 新增 `docs/lessons.md`，集中记录踩坑经验和可复用教训。
- 新增 `docs/develop/workflow.md`，合并项目执行、Git、提交、PR 和发布规则。
- 新增 `framelean-requirement-pool`、`framelean-feature-plan`、`framelean-validation`、`framelean-release` 和 `framelean-skill-create` 项目级 skills。
- 新增 FrameLean skills 共享预读协议，统一要求先读项目事实、再按需读取领域文档、相关源码和 Git 事实。

### Changed

- 将 `docs/archive/changelog.md` 迁移为根目录 `CHANGELOG.md`。
- 将 `docs/README.md` 收敛为短导航和维护规则，不再承载产品百科、构建说明或归档说明。
- 更新 `AGENTS.md`、`CLAUDE.md`、README 和 FrameLean 项目级 skills，使后续 agent 不再创建 `docs/archive/`、`docs/features/`、`docs/plans/` 或 `docs/product/roadmap.md`。
- 将旧的一 bug 一日志要求改为：版本级变化写 `CHANGELOG.md`，可复用经验写 `docs/lessons.md`，重要决策写 `docs/decisions/`。
- 将 `framelean-feature-design` 和 `framelean-feature-tasks` 合并为 `framelean-feature-plan`，临时设计和任务计划写入 `.workspace/plans/`。
- 将 `framelean-test-plan` 和 `framelean-review` 合并为 `framelean-validation`，统一承接验证计划、diff 审查和检查执行。
- 将 `framelean-delivery` 重构为交付前事实校准入口，负责扫描重要根文档和 `docs/` 当前事实，并输出 Markdown commit 信息和 PR description。
- 将正式 release 文档职责拆分到 `framelean-release`，按用户指定版本号讨论并产出 `docs/releases/vX.Y.Z/release.md`。

### Removed

- 删除旧 `docs/archive/`、`docs/features/`、`docs/plans/` 和 `docs/product/` 入口。
- 删除独立的 `docs/develop/project-workflow.md` 和 `docs/develop/git-workflow.md`，由 `docs/develop/workflow.md` 统一承接。
- 删除旧 `framelean-feature-design`、`framelean-feature-tasks`、`framelean-test-plan` 和 `framelean-review` 项目级 skill 目录。

### Verified

- 已扫描并更新旧文档路径和项目级 skill 规则引用。

## 2026-06-07｜v1.1.5｜No Release

今天完成工作台主题和交互体验整理，补齐深浅主题切换、响应式尺寸、任务拖拽排序和相关文档，并修复 QMC 上游 `qmc-decrypt` 构建和运行时探测脚本。

### Added

- 新增 FrameLean 主题 token 和深色配色，工作台顶部栏新增深浅主题切换按钮，主题偏好保存到 `settings.theme_mode`。
- `main()` 启动前读取轻量 `theme_prefs.json` 缓存并注入初始主题，避免等待 SQLite / Drift 初始化完成才确定首帧主题。
- 接入 `flutter_screenutil`，工作台和主题文本按桌面基准尺寸适配，并限制桌面大窗口不放大字体。
- 任务列表新增拖拽手柄，使用 `ReorderableListView` 调整任务顺序并复用现有排序持久化逻辑。
- 设置弹窗顶部媒体类型切换复用任务配置卡中的分段切换组件。
- 新增工作台 UI 刷新、主题切换设计文档，并新增 `ReorderableListView` / `Tooltip` 拖拽布局断言问题日志。
- 新增任务排序 use case、仓储 sort-only 持久化和主题缓存启动自愈的回归测试。

### Changed

- 工作台、任务列表、顶部栏、底部栏、弹窗、通知、表单控件、状态标签、进度条和滑杆颜色统一改为从 `FrameLeanColors` 主题 token 读取。
- 图片质量和视频目标体积分段滑杆在深色主题下使用主色作为圆形拖拽点，避免深色 thumb 与弹窗背景混在一起。
- README、文档入口、技术栈、数据模型和测试计划更新为当前媒体处理、主题切换、schema 15 和测试入口事实。
- 任务执行期间状态轮询间隔从 500ms 延长到 1000ms，并新增 `_taskListHasChanged` 变更检测，仅在任务 id / status / progress 实际变化时触发 UI 更新，避免无变化的无效全量重建。
- 工作台 `syncSelectedTaskIdAfterBuild`、`syncSelectedTaskConfigAfterBuild`、`syncQualityPresetAfterBuild` 从 `build()` 内移到 `ref.listen` 回调中触发，仅在任务列表数据变化时执行，不再随拖拽导入状态、主题切换等无关重建调度 deferred `setState`。
- 深浅主题切换使用 `MaterialApp.router` 内建主题动画参数，交由 Flutter 的 `AnimatedTheme` 处理过渡。
- 队列执行语义改为以任务列表顺序为唯一队列顺序：底部开始按实时列表顺序选择等待中 / 已暂停任务，运行中调整任务顺序会影响后续任务；任务行开始保留插队行为，不修改列表排序。
- 任务排序持久化改为只更新 `sort_order`，避免拖拽排序用旧任务快照覆盖运行中任务的进度、状态、错误或输出路径。
- 工作台任务列表变更监听改为 `listenManual(..., fireImmediately: true)`，预热 `AsyncData` 下也能同步选中任务、配置和质量预设。
- 深浅主题动画交回 `MaterialApp.router` 的 `themeAnimationDuration` / `themeAnimationCurve`，不再手写 `ThemeData.lerp` 包装层。
- 主题启动缓存明确为 `theme_prefs.json` 首帧镜像；启动后异步读取 DB，并以 `settings.theme_mode` 为准更新应用主题和重写缓存。
- `.claude/settings.local.json` 从共享提交中移除，并加入 `.gitignore` 作为本机配置。

### Fixed

- 修复 Drift 数据库迁移在开发阶段反复打包时偶发报 `SqliteException: duplicate column name` 的问题。根因是 Drift `onCreate` 直接创建包含所有当前列的完整表结构，在某些边缘情况下列在迁移前已存在，`ALTER TABLE ADD COLUMN` 重复添加导致启动时报“任务列表读取失败”。修复方案：新增 `_safeAddColumn` helper，所有 `migrator.addColumn` 调用改为幂等添加，遇 "duplicate column" 错误时安全跳过。
- 修复 `ReorderableListView` 拖拽任务项时，任务行内部 `Tooltip` / `OverlayPortal` 在拖拽 overlay 重挂载期间触发 `_RenderLayoutBuilder was mutated in _RenderLayoutBuilder.performLayout` 的问题；拖拽列表项内关闭 tooltip wrapper，并用 `Semantics` 保留无障碍标签。
- 修复 macOS / Windows `qmc-decrypt` 构建脚本误用 `--version` 导致构建后验证失败的问题；当前锁定的上游 CLI 只支持 `--help` 探测。
- 修复直接使用上游 `qmc-decrypt` 时的运行时可用性探测和文档契约，避免把 FrameLean wrapper 的 `--version` 要求错误套到上游二进制。
- 修复任务拖拽排序松手后，被移动任务及其之间的所有任务项预览图和标题闪烁的问题；根因是 `reorderTasks` 异步等待 DB 持久化后才更新 state，与 `ReorderableListView` 期望的同步数据更新产生时序冲突，改为乐观更新：先从内存 state 计算重排结果立即更新 UI，再异步持久化到 DB。
- 修复底部暂停按钮文案为“暂停所有任务”但实际逐个调用单任务暂停、可能触发队列继续执行的问题；底部暂停现在只暂停当前执行上下文并停止自动续跑。
- 修复拖拽排序后台持久化失败会变成未处理异步错误的问题；页面现在捕获失败并提示，notifier 会刷新仓储顺序恢复一致性。
- 修复图片和音频任务没有预览图时仍显示视频占位图标的问题；任务列表和任务详情源文件摘要现在按视频 / 图片 / 音频类型显示对应占位图标。

### Verified

- 通过 `dart analyze lib/`。
- 通过 `git diff --check`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/widget_test.dart`，覆盖媒体类型占位图标回归测试。
- 通过 `flutter test test/bundled_proprietary_audio_adapter_registry_test.dart`。
- 通过 `scripts/build/build_qmc_decrypt_macos_arm64.sh`。

## 2026-06-06｜v1.1.5｜No Release

今天完成仓库根目录结构治理，作为 `feature/media-processing` 的工程整理内容。

### Changed

- 将根目录 `NOTICE` 移入 `legal/NOTICE.md`，保留根目录 `LICENSE` 作为项目许可证发现入口。
- 将构建和发布脚本拆分到 `scripts/build/` 与 `scripts/release/`。
- 将本地参考、临时样本和工具状态迁入 `.workspace/`，并通过 `.gitignore` 排除。
- 更新 macOS / Windows 打包路径和法律材料复制配置。
- 扩展常规媒体输入格式识别，覆盖更多视频、图片和音频扩展名。
- 图片导出新增 BMP、TIFF、GIF；音频导出新增 AIFF、WMA、Opus 和 Ogg Opus。
- 新增本地专有音频导入适配边界：NCM 使用 Dart 原生还原，MGG / MFLAC 通过 QMC 外部适配器运行时处理，并兼容直接放置 `qmc-decrypt`。
- macOS 内置 FFmpeg 构建脚本新增 `libmp3lame`、`libwebp`、`libopus` 静态构建和启用参数；macOS / Windows 发布脚本会校验关键编码器是否存在。
- 统一任务配置百分比滑杆样式：视频目标体积右侧显示 `压缩体积XX%`，图片质量复用分段百分比滑杆并显示 `保留XX%的质量`。

### Fixed

- 音频 MP3 输出会在命令构造阶段检查当前 FFmpeg 是否支持 `libmp3lame`，避免任务启动后才暴露 `Unknown encoder 'libmp3lame'`。
- 图片 WebP 输出会在命令构造阶段检查当前 FFmpeg 是否支持 `libwebp`，避免发布包运行时缺编码器才失败。

### Verified

- 通过 `git diff --check`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart`。
- 通过 `flutter test test/widget_test.dart test/app_settings_dialog_test.dart`。

## 2026-06-05｜v1.1.5｜No Release

今天拆分 FrameLean 项目级 workflow skills，降低单次 commit、PR、release 文案和测试计划请求的上下文负担。

### Added

- 新增 `framelean-feature-analysis`、`framelean-feature-design`、`framelean-feature-tasks`、`framelean-test-plan`、`framelean-implementation`、`framelean-review` 和 `framelean-delivery` 项目级 skills。
- 新增 `.agents/skills/README.md`，说明 FrameLean 项目级 skills 的触发场景、推荐流程和文档位置约定。
- 新增媒体处理扩展首个实现切片：`MediaTaskConfig`、视频 / 图片 / 音频分类型配置和通用输出格式。
- Drift schema 升级到 14，新增任务通用配置 JSON、图片分析字段和设置表预留的默认媒体配置 JSON 字段。
- 设置仓储启用 `default_media_config_json` 读写，并保留旧视频默认字段兼容。
- 应用设置弹窗支持保存默认视频、图片和音频处理配置。
- FFprobe 支持纯音频和静态图片分析；FFmpeg 命令规划支持图片和音频基础输出计划。

### Changed

- 将 `framelean-workflow` 改为轻量路由入口，按请求路由到功能分析、设计、任务、测试计划、实现、审查验证或交付收尾 skill。
- 将 API 测试链规范改造为 FrameLean 测试计划 skill 的可选 API/服务端测试章节，普通桌面应用功能测试项优先来自 `docs/develop/test-plan.md`。
- 将 commit 详情、PR 描述、release description、changelog、bug log 和功能网归档收敛到 `framelean-delivery`。
- 文档入口补充 `docs/features/` 的功能级分析、设计、任务、测试计划和功能网归档用途。
- 导入、文件选择、输出路径、完成弹窗、关于弹窗和任务空态文案从视频专用表述收敛为通用媒体处理表述。
- 图片任务使用步骤型进度和源图缩略图；音频任务输出命令使用 `-vn` 禁用视频流。
- 图片任务配置面板显示图片格式、分辨率、质量和保留元数据开关；质量默认 100%，默认不保留元数据，图片编码由后台按格式推导。
- 更新媒体处理设计、任务、测试计划、数据模型、架构、技术栈、测试计划和路线图文档，明确图片 / 音频配置面板能力和剩余默认设置边界。

### Verified

- 通过 Ruby YAML 解析检查全部 `framelean-*` skill frontmatter。
- 通过 Ruby YAML 解析检查全部 `agents/openai.yaml`。
- 通过 `git diff --check`。
- 通过 `dart run build_runner build --delete-conflicting-outputs`。
- 通过当前变更 Dart 文件的 `dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。

## 2026-06-04｜v1.1.5｜No Release

调整关于弹窗的项目仓库入口，并删除托管更新联调实现。

### Added

- 关于弹窗底部左侧新增 GitHub 和 Gitee 图片图标入口。

### Changed

- 移除关于弹窗标题栏右侧 GitHub 图标和底部左侧“检查更新”按钮。
- GitHub / Gitee 项目入口统一使用系统外链打开逻辑。
- 基于当前系统设计尚未稳定、域名备案相关准备尚未完成，删除客户端更新检查、更新包下载、托管更新服务联调代码和本地 Release 探测脚本。
- 删除 `server/` 后端实验目录，并移除 `.gitignore` 中对 `/server/` 的忽略规则。
- 清理当前开发文档中的托管更新服务、接口、构建参数和验证说明。

### Verified

- 通过 `flutter pub get`。
- 通过 `dart format lib/features/workbench/pages/workbench_page.dart lib/application/services/framelean_build_info.dart lib/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart test/app_settings_dialog_test.dart test/workbench_about_dialog_test.dart`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `git diff --check`。

## 2026-06-03｜v1.1.5｜No Release

今天统一需求完成后的最终交付包，并继续推进自托管更新前端下载和安装包打开交互。

### Added

- 新增更新包下载器抽象和 HTTP 实现，支持下载进度、`.part` 临时文件、SHA-256 校验和失败清理。
- “发现新版本”弹窗新增下载更新、下载进度、下载完成、显示文件、打开 DMG 和 Windows 安装器启动交互。
- 新增更新会话申请接口，客户端使用本地安装 ID 换取短期更新 Token。
- 新增本地安装 ID 持久化和服务端下载事件记录 / 重复下载限流。
- 新增更新包下载器单元测试和更新弹窗下载 / 安装交互 widget 测试。

### Changed

- `framelean-workflow` Gate 6 改为要求在文档、changelog、同步和验证完成后始终输出 commit 详情和详细 PR 文案。
- PR description 固定使用中文标题：变更概览、背景与目标、实现详情、验证结果、风险与回滚、文档与变更记录、评审重点。
- Release description 固定使用中文标题：版本摘要、主要变更、验证与兼容、发布产物、已知风险、升级与回滚说明、关联记录。
- 项目 workflow 和 Git workflow 文档同步记录最终交付包、commit 详情和固定模板要求。
- 自托管更新文档补充客户端下载、校验、保存目录、打开安装包和手动验证边界。
- 更新服务鉴权从 HMAC 请求签名改为短期更新会话 Token，客户端不再内置静态 `FRAMELEAN_UPDATE_TOKEN`。

### Fixed

- 加固 FFmpeg 队列 runner 异步测试等待逻辑，避免默认并发全量测试中后台观测收尾尚未完成就断言任务状态。

### Verified

- 通过 `flutter test test/app_update_package_downloader_test.dart test/update_available_dialog_test.dart`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `cargo fmt --manifest-path server/update-service/Cargo.toml --check`。
- 通过 `cargo test --manifest-path server/update-service/Cargo.toml`。
- 通过 `git diff --check`。

## 2026-05-29｜v1.1.5｜No Release

今天开始自托管更新能力的第一阶段实现，先接入关于入口和客户端更新检查骨架，并清理旧的第三方 Release 更新源。

### Added

- 首页白色安全区新增关于入口，关于弹窗提供 GitHub 项目入口和检查更新入口。
- 新增应用版本比较、自托管更新接口解析和 macOS DMG 更新信息识别。
- 新增 Rust 自有更新服务，提供版本检查、版本日志、平台包信息和短期签名下载接口。
- 新增更新接口 HMAC 请求签名，客户端持久化安装级 client id 并为每次请求生成 nonce。
- 检查更新失败时对用户显示统一重试提示，内部保留 HTTP 状态码、TLS 握手失败、连接超时和 DNS 解析失败等诊断细节。

### Changed

- `http` 作为直接依赖用于更新检查请求。
- `crypto` 作为直接依赖用于更新接口 HMAC-SHA256 请求签名。
- 检查更新从 GitHub / Gitee Releases 改为请求自建更新接口，并通过 `FRAMELEAN_UPDATE_BASE_URL` 和 `FRAMELEAN_UPDATE_HMAC_SECRET` 配置接口地址和签名密钥。
- 发布流程文档移除 Cloudflare Workers / R2 更新源说明，后续改为自有服务器托管。

### Fixed

- 移除 GitHub / Gitee Release 同步 Action 和脚本，避免更新包同步流程受第三方 Release 上传速度影响。
- 移除 Cloudflare Worker / R2 更新后端残留，避免和后续 Rust 自有服务器实现并存。

### Verified

- 通过 `cargo fmt --manifest-path server/update-service/Cargo.toml --check`。
- 通过 `cargo test --manifest-path server/update-service/Cargo.toml`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `git diff --check`。

## 2026-05-29｜v1.1.5｜Release

今天完成 v1.1.5 发布准备，统一应用版本、macOS / Windows 发布产物命名、Windows zip 解压目录和 changelog 记录格式。

### Changed

- 将应用版本升级为 `v1.1.5`。
- macOS DMG 产物改为按 `pubspec.yaml` 语义化版本生成 `FrameLean-v1.1.5.dmg`。
- Windows zip 产物保持 `FrameLean-v1.1.5-windows-x64.zip`，并在压缩包内使用 `FrameLean-v1.1.5-windows-x64/` 作为顶层目录。
- release policy、Git 工作流和 changelog 记录规则统一为日期、版本号、Release 状态三段式格式。

### Verified

- 通过 `bash -n scripts/build_dmg_macos.sh`。
- 通过 `git diff --check`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `scripts/build_dmg_macos.sh`，生成并校验 `build/macos/Build/Products/Release/FrameLean-v1.1.5.dmg`。

## 2026-05-28｜v1.1.5｜No Release

今天主要完成 Windows 窗口行为、iPhone MOV 兼容、执行日志和设置即时生效修复，作为 v1.1.5 发布候选内容。

### Changed

- Windows 启动窗口改为按主屏幕工作区居中显示。
- Windows 管理员模式启动时显示拖拽限制提示，并提供“普通模式重启”操作。
- 压缩完成弹窗简化为小型结果弹窗，只展示压缩前后体积、单行可复制导出路径、取消和打开文件存放位置。
- FFprobe 分析结果新增可转码主音频流索引，FFmpeg 命令从映射所有音频流改为映射单个可用音频流。
- 自动编码后端在 Apple HDR / HVC1 / 10-bit MOV 等高风险源上优先使用可用的软件编码；显式选择 VideoToolbox 时仍尊重用户选择。
- 音频输出默认使用 FFmpeg 原生 `aac`，不再默认优先 `aac_at`。

### Fixed

- 修复 macOS / Windows 大小写不敏感文件系统上，大写 `.MOV` 源文件可能因输出路径只差大小写而触发 FFmpeg 原地覆盖失败的问题。
- FFmpeg 执行失败时保留 stderr 尾部错误信息，避免只显示退出码导致 MOV 压缩失败原因不可见。
- 修复 iPhone MOV 中 Apple Positional Audio / APAC 被 `-map 0:a?` 一起映射后，FFmpeg 因 `none` 音频流无解码器而失败的问题。
- 修复执行日志写入任务实体后又被任务状态保存覆盖，导致失败后日志窗口为空的问题；日志窗口现在读取临时 FFmpeg 日志文件。
- 修复应用设置保存后仅对新导入任务生效、已有任务不更新默认配置的问题；现在设置保存时会立即更新所有待处理（pending / failed / cancelled）任务的压缩配置。

### Verified

- 通过 `dart run build_runner build --delete-conflicting-outputs`。
- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/ffmpeg_command_builder_test.dart test/ffprobe_media_analyzer_test.dart test/ffmpeg_task_queue_runner_test.dart test/ffmpeg_process_observer_test.dart test/widget_test.dart`。
- 通过 `flutter test test/file_extension_media_kind_resolver_test.dart test/ffmpeg_command_builder_test.dart test/ffmpeg_process_observer_test.dart`。
- 通过 `flutter test test/widget_test.dart`。

## 2026-05-27｜v1.1.0｜Release

今天主要完成 Windows 桌面兼容修复、FFmpeg 输出参数优化、Windows 发布包自动化和 zip 布局修复，并将全局字体、项目级 workflow 和 `v1.1.0` 发布准备纳入本次发布。

### Added

- 新增 FFprobe 分析字段，覆盖像素格式、位深、色彩范围、色彩矩阵、传递曲线、色彩原色、帧率、宽高比、旋转、场序和音频声道布局。
- 新增 FFmpeg 命令构造能力，包含显式视频 / 音频流映射、BT.709 SDR 输出色彩标签、Lanczos 缩放、SAR 归一化、音频声道 / 采样率输出和 AudioToolbox AAC 优先策略。
- 新增 FFmpeg 进程控制抽象，由 application 层定义暂停、继续和终止能力，infrastructure 层负责具体平台实现。
- 新增 Windows runner 原生进程控制通道，通过线程挂起和恢复支持 Windows 上的 FFmpeg 真暂停 / 继续。
- 已完成任务新增“重来”入口，任务列表和完成弹窗都可以从源文件检查和媒体分析重新开始。
- 新增 GitHub Actions Windows 打包 workflow，可在 Windows runner 上恢复 FFmpeg 运行时并调用 `scripts\release\build_windows.ps1` 生成发布 zip。
- 新增 `docs/develop/project-workflow.md` 和 `.agents/skills/framelean-workflow/`，记录 FrameLean 项目级需求、分支、测试、实现、验证和 PR 准备流程。

### Changed

- 将应用版本升级为 `v1.1.0`，同步发布文档、路线图、Windows 产物示例路径和 Windows 版本 fallback。
- 将应用全局字体切换为 Alibaba PuHuiTi，并接入 Regular、Medium、SemiBold 和 Bold 四个字重资源。
- 压缩输出默认通过滤镜链统一到 `yuv420p`、limited range、BT.709，并避免分辨率预设把小尺寸源视频向上放大。
- VideoToolbox HDR 源素材优先使用 `scale_vt` 转为 SDR BT.709 输出。
- Drift `tasks` schema 升级到 12，用于持久化新增 FFprobe 分析字段。
- 队列执行器不再直接依赖 `ProcessSignal`，暂停、继续和取消统一通过 `FfmpegProcessController` 调用。
- Windows 工作台顶部新增通知安全区，顶部通知会显示在安全区内，避免遮挡任务列表第一项操作按钮。
- Windows 打包脚本改为逐文件写入 zip，并强制使用标准 `/` 路径分隔符；打包完成后校验关键运行时和核心文件布局。
- Windows FFmpeg 依赖 zip 和校验文件现在作为本地 / Release 资源处理，避免误提交到源码仓库。
- 项目 agent 规则从 Git-only skill 迁移到 `framelean-workflow`，并更新 `AGENTS.md`、`CLAUDE.md` 和文档入口。

### Fixed

- 修复 Windows 点击暂停后再继续时进度条卡住、任务不再完成的问题。
- 修复任务完成后缺少清晰“重来”操作的问题。
- 修复单任务列表场景下顶部通知遮挡第一项右侧按钮的问题。
- 修复 Windows 打开文件所在位置时，包含空格或中文的路径可能被 Explorer 解析失败的问题。
- 修复 Windows 发布 zip 内部条目使用反斜杠路径，可能导致解压后 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe` 不在应用可识别目录的问题。

### Verified

- 通过 `flutter pub get`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 `flutter test test/workbench_file_revealer_test.dart`。
- 通过 `flutter test test/ffprobe_media_analyzer_test.dart test/ffmpeg_encoder_capabilities_test.dart test/ffmpeg_command_builder_test.dart`。
- 通过 workflow YAML 解析检查、旧 skill 路径引用扫描、尾随空白检查和 `git diff --check`。
- 通过 `unzip -l /Users/leftzhou/Downloads/FrameLean-v1.0.0-windows-x64.zip` 复现旧包中存在 `ffmpeg\ffmpeg.exe` 条目。
- 通过 GitHub Actions 日志确认旧脚本缺少 `System.IO.Compression` 类型加载。

## 2026-05-26｜v1.0.0｜Release

今天完成 FrameLean 更名后的 v1.0.0 桌面视频压缩发布。

### Added

- 提供完整的视频压缩工作流，支持拖拽或选择导入视频、分析源文件信息、配置压缩参数并执行任务。
- 支持推荐方案和自定义目标体积两种压缩方式，可展示预计输出大小、目标视频码率和目标音频码率。
- 支持输出格式、视频编码、分辨率、输出目录和输出文件名配置。
- 支持任务队列、进度显示、暂停、继续、取消、删除、重命名和完成后打开输出位置。
- 支持压缩前后预览帧、视频缩略图和任务状态展示。
- 支持应用设置弹窗，可配置默认压缩方案、默认导出地址、默认导出文件名和自定义 FFmpeg / FFprobe 路径。
- 提供 macOS Apple Silicon 和 Windows x64 发布包。

### Changed

- 统一产品显示名为 FrameLean，中文名为帧轻。
- 统一内部包名、应用标识、平台元数据、构建脚本、发布产物名称和法律资料。
- 完善 Git 工作流和 agent 提交规则，要求每次提交前记录 changelog，bug 修复同步补充归档日志。
- 补充分支创建失败诊断规则，区分真实 ref 路径冲突和沙盒或权限导致的 `.git` 写入失败。

### Fixed

- 修复推荐方案自动改变视频分辨率的问题。
- 修复自动编码后端选择失效的问题。
- 修复已压缩任务仍显示目标体积预估的问题。
- 修复部分缓存状态导致任务显示或配置刷新不及时的问题。
- 修复 Windows 导入部分 MP4 后 FFprobe 全量 JSON 元数据触发字符串转义解析失败的问题。

### Verified

- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 macOS DMG 打包验证。

## 2026-05-26｜Machining v1.5.0+1｜No Release

今天主要整理分层架构、工作台交互和弹窗风格，作为旧 Machining 阶段的未发布开发记录。

### Added

- 新增 Application Use Cases，覆盖应用设置、任务导入、分析、恢复、重试、排序、队列启动、单任务开始 / 暂停 / 继续、删除、清空和预览帧生成。
- 新增持久化兼容层和 `CompressionModeMapper`，把历史 `smart`、`quality` 压缩模式映射到当前 `preset`。
- 新增 `flutter_animate` 依赖，用于工作台右上角通知的进入和退出动画。
- 新增工作台统一弹窗基础组件和弹窗风格测试。

### Changed

- Application 服务按 `input_runtime`、`ffmpeg_planning`、`execution` 分组，UI 状态入口通过 Use Cases 进入业务流程。
- Infrastructure provider 按数据库、仓储、输入运行时、FFmpeg 规划和执行拆分。
- FFmpeg 命令构造拆分为输出路径、编码器解析、视频参数、命令步骤、日志提示和格式化 helper。
- features/workbench 拆分为页面入口、layout、dialogs、overlays、configuration、form controls 和 media task list 组件。
- 压缩模式文案调整为“推荐方案选项”和“自定义目标体积”，数据库当前写入值调整为 `preset` / `targetSize`。
- 任务配置弹窗中的“已修改”“已压缩”移到底部按钮同排左侧显示。

### Fixed

- 修正未实质改变配置时仍显示“已修改”的判断。
- 统一压缩确认、导入失败、清空任务和重命名弹窗的视觉风格，移除生产代码中的默认 `AlertDialog`。
- 移除已废弃的项目参考对比 HTML 文档引用。

## 2026-05-20｜Machining v1.5.0+1｜Release

今天主要完成旧 Machining 阶段的应用设置、发布准备、运行时打包和许可证分发整理。

### Added

- 增加 Windows x64 运行时打包和基础兼容支持。
- 增加 macOS / Windows GPU 编码能力检测，支持自动选择可用编码后端。
- 新增视频缩略图生成能力，并接入任务列表和配置界面。
- 新增智能压缩预设：均衡推荐、微信发送、清晰优先、体积优先。
- 新增目标体积压缩能力，可根据目标大小和视频时长估算压缩码率。
- 新增压缩结果预估，展示预计输出大小、目标视频码率和目标音频码率。
- 新增应用设置弹窗，支持默认压缩方案、默认导出地址、默认导出文件名、自定义 FFmpeg / FFprobe 路径和高级设置。
- 新增应用设置持久化字段，新任务会读取默认输出目录、智能压缩预设、输出编码和文件名模板。
- 新增 GPLv3+、第三方声明、源码获取说明、FFmpeg 构建信息和 macOS DMG 打包验证脚本。

### Changed

- 重构主界面，将顶部栏、底部栏、任务列表、预览区、文件信息、导出路径和配置面板拆分为独立模块。
- 重构任务详情设置弹窗，集中配置输出格式、编码、分辨率、压缩模式和输出文件名。
- 将目标体积模式调整为比例滑杆，降低手动输入成本。
- 完善缺失源文件重新指定流程。
- 将“在 Finder 中打开”调整为跨平台的“打开文件所在位置”。
- 将工作台通知改为顶部浮层，避免遮挡底部操作按钮。
- 移除未完成的 `/settings` 占位路由；应用设置现在从工作台弹窗打开。
- 将格式检查调整为只处理 Git 跟踪的 Dart 文件，避免误改本地工作树目录。
- 更新 macOS / Windows 发布资料复制和内置 FFmpeg 验证路径。
- 同步 README、文档中心、路线图、技术栈、数据模型和许可证分发文档中的版本事实。

### Fixed

- 修复默认压缩会改变视频分辨率的问题，推荐预设不再自动调整分辨率。
- 修复默认 CPU / GPU 编码选择失效的问题，默认编码后端恢复为自动选择。
- 修复已压缩任务仍显示目标体积预估的问题。
- 修复压缩完成弹窗内容展示异常，并优化输出文件路径和打开位置操作。
- 修复部分缓存状态导致任务显示或配置刷新不及时的问题。
- 排除 `worktrees/` 目录，避免其他工作树影响当前分支的静态分析结果。
- 移除设置页占位路由，避免发布版本暴露未完成页面。

### Verified

- 通过 `git ls-files '*.dart' | xargs dart format --set-exit-if-changed`。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- 通过 macOS DMG 打包测试。

## 2026-05-15｜Machining v1.3.0+1｜No Release

今天主要重构主界面和压缩配置相关代码，并修复一批已知交互问题。

### Added

- 添加应用图标资源，并更新 macOS / Windows 图标配置。
- 新增智能压缩预设、压缩模式和压缩结果预估能力。
- 补充压缩预估、编码器能力、分辨率预设和 FFmpeg 命令生成相关测试。

### Changed

- 重构主界面代码，将顶部栏、底部栏、任务列表、预览区、文件信息、导出路径和配置面板拆分为独立模块。
- 重构任务详情设置弹窗，优化压缩参数配置体验。
- 完善 FFmpeg 编码器能力判断、命令生成、任务执行和进度观测逻辑。
- 将“在 Finder 中打开”调整为跨平台的“打开文件所在位置”。

### Fixed

- 修复压缩完成弹窗内容展示异常，并优化输出文件路径和打开位置操作。
- 将工作台通知改为顶部浮层，避免 SnackBar 遮挡底部操作按钮。
- 修复默认压缩会改变视频分辨率的问题，推荐预设不再自动调整分辨率。
- 修复默认 CPU / GPU 编码选择失效的问题，默认编码后端恢复为自动选择。

## 2026-05-14｜Machining v1.2.0+1｜No Release

今天主要完成主界面重构、视频缩略图能力和文档目录整理。

### Added

- 新增视频缩略图生成能力，并接入任务列表和配置相关界面。
- 新增文档入口和目录 README。

### Changed

- 更新为更轻便的主界面视觉风格。
- 优化任务配置窗口打开方式和应用窗口顶部样式。
- 整理文档目录结构，拆分产品、架构、开发、功能、参考资料和历史归档。
- 将历史开发日志迁移到 `docs/archive/logs/`。

## 2026-05-07｜Machining v1.1.0+1｜No Release

今天主要推进 Windows 兼容、GPU 编码能力和运行时资源配置。

### Added

- 增加 Windows 运行时打包和基础兼容支持。
- 为 macOS 和 Windows 增加 GPU 编码加速相关支持。
- 新增 FFmpeg 编码器能力检测接口。

### Changed

- 调整 FFmpeg 定位、命令构建、任务执行和预览帧生成逻辑，以适配不同平台和编码器后端。
- 更新 Windows 入口、窗口行为和运行时资源配置。
- 更新 README 和 Windows 运行时打包说明。

## 2026-05-06｜Machining v1.0.0+1｜Release

今天初始化旧 Machining 阶段的核心视频压缩应用、工程结构和基础文档。

### Added

- 提供完整的视频压缩工作流，支持拖拽或选择导入视频并自动分析视频信息。
- 支持生成压缩前后预览帧。
- 支持配置输出格式、编码方式、分辨率、压缩质量、输出目录和文件名。
- 支持任务队列处理、进度显示、暂停、继续、取消、删除和重命名。
- 支持任务完成后直接在 Finder 中打开输出位置。
- 内置 macOS arm64 FFmpeg / FFprobe，支持 libx264 编码，不依赖 Homebrew。
- 初始化 Machining v1.0.0 核心功能和 Flutter 桌面应用基础结构。
- 实现本地媒体任务、应用设置、任务队列和 SQLite 持久化。
- 接入 FFprobe 媒体分析、预览帧生成、FFmpeg 压缩命令构建和进程观测。
- 支持 H.264 / HEVC、输出格式、分辨率、任务状态和压缩配置等核心模型。
- 增加命令行验证入口和 macOS arm64 FFmpeg 构建脚本。
- 初始化产品、需求、设计、架构、测试、路线图和开发日志文档。
- 增加核心服务测试和基础 Widget 测试。
