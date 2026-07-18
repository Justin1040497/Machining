# 踩坑记录与经验总结

这个文件只记录可复用经验，不写每日日志。条目应能帮助后续避免同类错误。

## 资源恢复补位应事件驱动且不可重入

经验：

- 调度器暂时无租约时，启动入口必须立即返回排队状态；如果在 `startTask()` 内同步调用后续补位，会反复选中同一个任务并形成递归或忙循环。
- 租约释放和资源压力恢复应提供只读容量事件，由单独的 queue pump 异步补位；同一时段的多个事件需要合并，保证一次容量恢复只触发一轮补位。
- 当前补位轮次一旦遇到资源等待就应结束，避免重复执行输入准备、输出预检和命令构造等有副作用或高成本操作。

关联：

- `lib/application/services/execution/execution_slot_coordinator.dart`
- `lib/application/services/execution/media_work_scheduler.dart`
- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`

## 短异步任务完成后不要依赖轮询刷新 UI

经验：

- 分析任务可能在第一次轮询前就完成；只观察某个中间快照或固定延时轮询，会错过状态变化并让仓储已完成、界面仍显示等待中的状态长期不一致。
- 批量入队后应等待队列达到空闲，再从仓储刷新一次列表；队列内部负责 `awaitingAnalysis -> analyzing -> pending/failed` 的语义状态转换。
- 停止并发队列时要先阻止新任务、等待活跃清理完成，再关闭状态流，避免异步回调写入已关闭的 stream。

关联：

- `lib/application/services/analysis/media_analysis_queue.dart`
- `lib/features/workbench/providers/media_task_notifier.dart`

## 串行命令区内不要调用可能无限等待的异步方法

经验：

- 串行命令锁（如 `_serializeCommand` 的 FIFO `Completer` 链）内的代码如果调用另一个也依赖同一串行区才能完成的等待（如 `scheduler.acquire()` 创建的 `Completer`），会形成死锁。
- 当资源不足时，`acquire()` 创建永不完成的 `Completer` 并等待；而释放资源的代码（`release()`）也需要先进入同一串行区。结果：`startTask` 占着串行区等资源，释放资源的代码等串行区，形成循环等待。
- 修复方案：(1) 提供非阻塞 `tryAcquire()`，资源不足时立即返回 `null` 而不是创建 `Completer`；(2) 资源释放移到串行区外执行；(3) 释放操作幂等化，立即清空引用后再 best-effort 释放。
- 通用原则：串行命令区内的代码必须是"快进快出"的，不应包含任何可能需要等待外部事件才能完成的异步操作。

关联：

- 决策：`docs/decisions/260712-scheduler-tryacquire-deadlock.md`
- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`
- `lib/application/services/execution/media_work_scheduler.dart`

## 基于 Completer 的资源等待要提供非阻塞变体

经验：

- 基于 `Completer` 的资源等待模式（如 `MediaWorkScheduler.acquire()`）在资源紧张时会创建一个可能永不完成的 Future。
- 这种模式下，调用方如果处于任何互斥区域（串行锁、事务、状态机关键段），就会形成死锁。
- 任何基于 `Completer` 等待的资源分配器都应同时提供非阻塞 `tryXxx()` 变体，让调用方在互斥区内安全使用。
- `tryAcquire()` 在资源不足时返回 `null`，调用方可以立即释放已准备的 IO 资源并返回排队状态，由外部轮询或事件驱动重新尝试。

关联：

- 决策：`docs/decisions/260712-scheduler-tryacquire-deadlock.md`
- `lib/application/services/execution/media_work_scheduler.dart`

## Windows 静默覆盖安装不应只相信退出码

经验：

- Inno Setup `/VERYSILENT /SUPPRESSMSGBOXES` 下安装可能因文件被占用而静默失败，但退出码仍为 0。
- 只按 PID 等主进程退出不够：进程列表消失后，Windows 文件锁可能仍需数秒释放；退出前启动的子进程也可能持有文件句柄。
- 可靠做法：(1) 确认进程退出后再等 2-3 秒；(2) `taskkill /F /IM <进程名>` 强杀残留；(3) 解析安装日志确认无错误行；(4) 安装后验证目标可执行文件版本号确认实际已覆盖。

关联：

- `tool/windows_updater_helper.dart`
- `installer/windows/FrameLean.iss`

## 依赖装配不要伪装成 infrastructure

经验：

- Riverpod Provider 同时连接 application、infrastructure 和 features 时，本质上属于应用 composition root，不是基础设施实现。
- 文件选择、外链打开、文件定位和主题缓存等平台行为，应先在 application 定义 port，再由 infrastructure 提供实现，由 `app/providers` 完成装配。
- 设置页、通知中心和工作台共同使用的展示组件应提升到 `app`，避免 feature 之间横向依赖。
- 分层约束需要自动化测试守住；仅靠目录命名和代码评审，依赖方向会在功能迭代中逐渐漂移。

关联：

- 决策：`docs/decisions/260614-clean-architecture-composition-root.md`
- 架构：`docs/develop/architecture.md`
- 测试计划：`docs/develop/test-plan.md`

## Drift 迁移新增列要幂等

经验：

- Drift `onCreate` 会按当前完整表结构建表。
- 开发阶段反复打包或迁移边界异常时，目标列可能已经存在。
- 后续新增列继续使用 `AppDatabase._safeAddColumn`，不要直接调用 `migrator.addColumn`。

关联：

- 决策：`docs/decisions/260607-drift-migration-safe-add-column.md`
- 数据模型：`docs/develop/data-model.md`

## ReorderableListView 需要同步更新列表数据

经验：

- `ReorderableListView.onReorder` 触发后，UI 数据应在同一帧同步更新。
- 如果先等待数据库持久化再更新 state，拖拽动画结束后会短暂回到旧顺序，再重建成新顺序，造成预览图和标题闪烁。
- 正确做法是先从当前内存 state 计算重排结果并乐观更新 UI，再后台持久化；持久化失败时刷新仓储顺序恢复一致性。

关联：

- 决策：`docs/decisions/260607-task-reorder-optimistic-update.md`
- 版本事实：`docs/releases/v1.1.5/workbench-theme-and-reorder.md`

## 拖拽列表项内避免 Tooltip overlay

经验：

- `ReorderableListView` 会把拖拽 item 放入 overlay。
- item 子树内的 `Tooltip` / `OverlayPortal` 在 overlay 重挂载期间可能触发 layout 阶段 mutation 断言。
- 拖拽列表项内关闭 tooltip wrapper，使用 `Semantics` 保留无障碍标签；普通非拖拽场景仍可保留 tooltip。

关联：

- 版本事实：`docs/releases/v1.1.5/workbench-theme-and-reorder.md`

## macOS Flutter 窗口要处理 first mouse

经验：

- macOS 非焦点窗口默认可能把第一下鼠标点击用于激活窗口，不一定交给 Flutter 控件。
- Flutter macOS 使用透明标题栏和 `.fullSizeContentView` 时，这个现象在 Debug 运行中更明显。
- `desktop_drop` 会向 FlutterView 添加覆盖窗口的原生 `NSView` 接收拖拽事件；只处理 FlutterView 不够，还要让插件注入的子视图也接受 first mouse。
- 修复应放在 macOS Runner 层，Dart 层的按钮防重复点击只能避免连续点击叠加动作，不能解决第一下被 AppKit 吃掉。

关联：

- 技术栈：`docs/develop/technology-stack.md`
- 测试计划：`docs/develop/test-plan.md`

## 主题启动缓存只能作为首帧镜像

经验：

- `settings.theme_mode` 是主题偏好的 source of truth。
- `theme_prefs.json` 只用于 `main()` 启动前快速决定首帧主题，避免深色偏好下先显示浅色再闪到深色。
- 启动后必须异步读取 DB；如果 DB 和缓存不一致，以 DB 为准更新应用状态并重写缓存。

关联：

- 版本事实：`docs/releases/v1.1.5/workbench-theme-and-reorder.md`

## FFmpeg 编码器能力要在命令构造前校验

经验：

- WebP 输出依赖 `libwebp`，MP3 输出依赖 `libmp3lame`，Opus / Ogg Opus 依赖 `libopus`。
- 如果等 FFmpeg 启动后才暴露 `Unknown encoder`，用户只能看到执行失败。
- 命令规划阶段应检查当前 runtime 能力，不满足时给出可读错误。

关联：

- 版本事实：`docs/releases/v1.1.5/media-processing.md`

## HDR 转 SDR 需要同时校验滤镜能力

经验：

- HDR10 / HLG 正确转 SDR 不能只靠 `scale` 或输出色彩标签，命令链路需要 `zscale` 和 `tonemap`。
- 如果 FFmpeg 没有启用 `libzimg`，HDR 转 SDR 会在运行时失败；发布脚本应像校验编码器一样校验 `zscale` / `tonemap`。
- Dolby Vision Profile 5 没有可直接当作 HDR10 使用的兼容层，首版应拒绝处理，避免生成变黑、偏紫或严重偏色的输出。

关联：

- 技术栈：`docs/develop/technology-stack.md`
- 测试计划：`docs/develop/test-plan.md`

## 第三方源码 autogen 依赖要在 CI 中完整固定

经验：

- 只安装 `autoconf` 不等于具备完整 autotools 构建环境；`autoreconf` 可能继续调用 `aclocal`、`automake` 和 GNU libtool。
- 使用上游 tag archive 时，即使大多数依赖包带有 `configure`，仍要按实际源码包验证是否需要 `autogen.sh`。
- CI workflow 和本地 README 的依赖列表要和脚本的 `require_command` 保持一致，否则 runner 会在第三方源码构建中途失败。

关联：

- 技术栈：`docs/develop/technology-stack.md`
- 发布脚本：`scripts/build/build_ffmpeg_macos_arch.sh`

## PowerShell 校验原生命令不要提前截断管道

经验：

- `native.exe -version | Select-Object -First 1` 可能在拿到首行后提前关闭管道，让原生命令留下非 0 exit code。
- 版本校验应先完整收集命令输出并保存 `$LASTEXITCODE`，确认成功后再只打印首行。
- 看到日志已经输出版本行但脚本仍报版本校验失败时，要优先怀疑管道截断或 `$LASTEXITCODE` 被后续命令污染。

关联：

- 发布脚本：`scripts/release/build_windows.ps1`
- 测试计划：`docs/develop/test-plan.md`

## Windows 用户可感知音效不要依赖 PowerShell

经验：

- 用户可感知的提示音如果通过 `powershell.exe` 启动脚本播放，可能被安全软件拦截，也会让发布包行为显得不可信。
- 轻量完成音效应优先使用 Flutter 音频插件或原生 API 通道，保持 application 层只有 `TaskCompletionSoundPlayer` 抽象。
- 播放失败仍应吞掉，不能影响任务完成通知、通知中心历史或队列收尾。

关联：

- 决策：`docs/decisions/260613-task-completion-sound-playback.md`
- 版本事实：`docs/releases/v1.2.0/task-completion-sounds.md`

## GitHub Actions artifact 解包目录不要硬编码

经验：

- `upload-artifact` 上传目录和 `download-artifact` 下载目录组合后，真实文件可能位于目标目录顶层，也可能多一层原始目录。
- 合并架构 slice 的脚本应在下载目录下寻找包含目标可执行文件的真实目录，再做 `lipo` 和架构校验。
- 报 `required executable not found` 时，不要只检查构建 slice 是否成功，也要检查 artifact 下载后的目录形状。

关联：

- 发布脚本：`scripts/build/build_ffmpeg_macos_universal.sh`
- 发布脚本：`scripts/build/build_qmc_decrypt_macos_universal.sh`

## 保持原始选项不要写成伪格式枚举

经验：

- “保持原始”是任务配置模式，不是媒体输出格式本身。
- 下拉框可以展示 `MOV（保持原始）` 或 `3840 × 2160（保持原始）`，但底层应保存真实格式 / 分辨率值和独立布尔状态。
- 初始化任务详情时要按媒体类型读取对应配置；图片和音频任务不能触碰视频专属编码器状态。

关联：

- 决策：`docs/decisions/260613-media-task-source-format-and-metadata.md`
- 版本事实：`docs/releases/v1.2.0/media-task-defaults-and-metadata.md`

## Windows 进程控制不能照搬 Unix signal

经验：

- macOS / Linux 可以用 `SIGSTOP` / `SIGCONT` 暂停和继续 FFmpeg 进程。
- Windows 没有等价语义，直接复用会导致 UI 状态和底层进程不同步，出现继续后进度卡住。
- application 层应依赖 `FfmpegProcessController` 抽象，由 infrastructure 分平台实现。

关联：

- 版本事实：`docs/releases/v1.1.0/windows-runtime-packaging.md`

## Windows zip 条目路径要强制使用标准分隔符

经验：

- Windows 打包脚本如果把 zip 条目写成反斜杠路径，解压后可能得到应用无法识别的 `ffmpeg\ffmpeg.exe` 条目。
- 发布 zip 需要逐文件写入并校验顶层目录、`ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe` 布局。

关联：

- 版本事实：`docs/releases/v1.1.0/windows-runtime-packaging.md`

## 直接使用上游 qmc-decrypt 时不要假设有 --version

经验：

- FrameLean wrapper 可以约定版本输出，但上游 `qmc-decrypt` 当前只适合用 `--help` 探测。
- 运行时注册表需要区分自有 adapter 和直接放置的上游二进制，避免构建后验证或运行时探测误失败。

关联：

- 版本事实：`docs/releases/v1.1.5/proprietary-audio-import.md`

## iPhone MOV 音频流映射要避开不可转码流

经验：

- iPhone MOV 可能包含 APAC / `none` 等不适合作为主转码音频的流。
- FFprobe 分析应记录可转码主音频流索引，FFmpeg 命令构造使用精确 `-map 0:<index>?`。
- 执行日志应保存到临时日志文件，避免被任务状态保存覆盖后用户看不到失败原因。

关联：

- 版本事实：`docs/releases/v1.1.0/ffmpeg-command-and-process-control.md`

## Windows attrib.exe 隐藏属性设置应是非致命操作

经验：

- `attrib.exe` 在受限环境中可能因权限、组策略或安全软件拦截而失败，但隐藏 partial 输出只是隐私保护手段，不应阻断整个任务。
- 把 `attrib.exe` 的失败当成致命错误会导致所有 Windows 输出任务被统一误判为"权限不足"。
- 正确做法：隐藏属性设置改为 best-effort，失败时只输出 stderr 警告，让任务正常继续。
- 同理，任何非关键辅助步骤都不应成为任务的单一失败点。

关联：

- `lib/infrastructure/services/execution/local_output_preflight_service.dart`
- `lib/application/services/execution/output_failure.dart`

## 不要预创建 FFmpeg 输出工作文件

经验：

- 在 FFmpeg 启动前预先 `File.create(recursive: true)` 创建输出工作文件看似无害，但会提前占用文件路径。
- 如果 FFmpeg 进程启动延迟或目录权限在创建和启动之间变化，预创建的文件会成为干扰因素。
- `ffmpeg -y` 本身会覆盖已存在文件，应用层不需要替 FFmpeg 创建输出。
- 正确做法：预检阶段只验证目录可写（探针文件创建/重命名/删除后立即清理），把实际工作文件创建交给 FFmpeg。

关联：

- `lib/infrastructure/services/execution/local_output_preflight_service.dart`

## 错误文本匹配要覆盖中英文双语

经验：

- FFmpeg 的 stderr 输出绝大多数是英文，不能只按中文关键词判断错误类型。
- 在 Windows 中文系统上，部分系统级错误信息可能以本地化语言出现，但 FFmpeg 子进程本身的错误仍是英文。
- 涉及操作系统错误码（如 Windows error 5/32/112）时，应优先用错误码映射，文本匹配只作为补充。
- 所有面向用户的错误分类都应同时检查中英文等价表达，例如 `permission denied` + `拒绝访问`、`sharing violation` + `文件被占用`。

关联：

- `lib/application/services/execution/ffmpeg_task_queue_runner.dart`
- `lib/application/services/execution/output_failure.dart`

## Reorderable 外部状态回调不要放在内部 setState 中

经验：

- reorderable fork 计算 gap 时可以在内部 `setState` 中更新自身 item 动画，但不能在这个闭包内直接调用会重建父列表的业务回调。
- 拖拽更新应合并到帧后回调；drop 决策与数据提交应分离，需要重建列表的排序提交等代理卸载后再执行。
- 外部接收如果需要跨出纵向列表，必须显式允许跨轴拖动；Flutter 原生 reorderable 默认会锁定主轴。

关联：

- 决策：`docs/decisions/260619-shared-reorderable-list.md`

## 少量固定批注箭头优先用显式约束而非寻路

经验：

- 工作台引导箭头只有三个固定用途（任务操作、全部开始、添加按钮），每个目标位置和允许绘制区域都是已知的。这种场景下用“安全视觉终点 + `maxLength` 限长 + `curveBias` 双段曲线偏移 + `targetDirection` 末端方向 + `clipRect` 裁剪区”显式约束即可，不要引入障碍物碰撞检测或多种子随机重试。
- 自动避障的代价在固定场景下不划算：路径采样碰撞检测和随机重试会在窗口尺寸变化时让箭头形态不稳定，还带来额外测试与维护成本；半成品寻路代码若未接入目标文件，会留下无法编译的死代码并污染 `flutter analyze`。
- 关键约束：终点是“视觉终点”而非目标中心点，必须停在目标外侧的背景空白区（任务卡片下方、按钮上方、底栏上方）；曲线随机扰动应限制在约 3.2px 以内的法向方向，禁止回头或自相交；裁剪只是最后一层保护，不能依赖裁剪制造半截箭头。
- 多个固定引导共存时，应先由共享布局划分互不重叠的安全通道，再让各内容组消费确定的起终点、文本矩形和裁剪区；空间不足时按产品优先级降级隐藏，不能让每组独立占用整块剩余空间后再依赖裁剪补救。
- 通用原则：当问题本质是“少量已知锚点的短批注”时，先用显式坐标和硬上限解决；只有当箭头数量、目标和障碍都动态未知时，才考虑寻路。

关联：

- 决策：`docs/decisions/260714-guide-arrow-safe-annotation.md`
- `lib/features/workbench/guide/arrow/doodle_arrow_geometry.dart`
- `lib/features/workbench/guide/arrow/doodle_arrow_painter.dart`
