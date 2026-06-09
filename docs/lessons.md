# 踩坑记录与经验总结

这个文件只记录可复用经验，不写每日日志。条目应能帮助后续避免同类错误。

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
