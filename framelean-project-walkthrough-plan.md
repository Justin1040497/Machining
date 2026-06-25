# FrameLean 项目讲解方案

> 目标：**你先吃透自己的项目，然后能对外讲清楚**。
>
> 这不是「教别人从零写 Flutter」的入门课，而是「带你读懂一个生产级桌面应用」的项目 walkthrough。
>
> 主角是 FrameLean 本身——它的架构决策、核心模块、技术亮点和踩过的坑。

---

## 0. 先定三件事（开场前自己想清楚）

| 问题 | 建议默认值 | 可调 |
|---|---|---|
| **讲给谁听** | 有 Flutter 基础的开发者（会写 Widget、懂 setState，但没做过完整桌面应用） | 若是纯新手，跳过第三部分的进程/编解码细节，只讲架构与状态管理 |
| **讲多长** | 45-60 分钟主线 + 15 分钟 Q&A | 砍掉模块6/7 可压到 30 分钟 |
| **讲完听者带走什么** | ① 一个本地媒体桌面应用的完整架构长什么样 ② Riverpod 在生产项目里怎么用 ③ FFmpeg 集成的工程化处理 ④ 真实项目踩坑经验 | — |

---

## 1. 你的知识自检清单（讲之前先过一遍）

讲别人之前，先确保自己答得上来这 20 题。答不上来的就去翻对应文件。

### 架构层
1. FrameLean 为什么用 Clean Architecture 分层？不分会怎样？（→ `docs/develop/architecture.md`「为什么使用这个架构」）
2. `domain` / `application` / `infrastructure` / `features` / `app` 各自的职责边界？依赖方向怎么约束？（→ architecture.md + `test/architecture_dependencies_test.dart`）
3. `library.dart` barrel 导出是什么？为什么要强制跨层导入走它？（→ `docs/decisions/260623-library-barrel-import-architecture.md`）
4. composition root 在哪？为什么 Riverpod provider 不放在 infrastructure？（→ `docs/lessons.md`「依赖装配不要伪装成 infrastructure」）

### 状态管理与 Riverpod
5. 项目用了哪几种 Provider 类型？分别对应什么场景？（→ architecture.md「Riverpod 组装方式」表）
6. `main.dart` 的 `ProviderScope(overrides: ...)` 在做什么？为什么不直接 `Provider((ref) => AppDatabase())`？（→ `lib/main.dart`）
7. `mediaTaskListProvider` 为什么是 `AsyncNotifierProvider` 而不是 `NotifierProvider`？`build()` 里做了什么？（→ `lib/features/workbench/providers/media_task_notifier.dart`）
8. `ref.watch` / `ref.read` / `ref.listen` / `ref.invalidate` / `ref.onDispose` 在项目里分别用在哪？（→ providers 目录扫一遍）
9. 任务列表状态怎么和 UI 解耦的？UI 层调用 notifier 还是直接改 state？（→ `media_task_notifier.dart`）

### FFmpeg 工程化
10. FFmpeg/FFprobe 运行时怎么定位的？优先级？（→ `LocalFfmpegLocator`）
11. 命令构造为什么不直接拼字符串？`DefaultFfmpegCommandBuilder` 拆了哪些 helper？（→ `services/ffmpeg_planning/`）
12. 队列执行的「受控并行」是怎么做的？资源守卫考虑了什么？（→ `ExecutionResourceGuard` + architecture.md「并行和资源保护」）
13. 暂停/继续为什么 macOS 用 SIGSTOP/SIGCONT，Windows 用 method channel？（→ `docs/lessons.md`「Windows 进程控制不能照搬 Unix signal」）
14. partial 输出保护是什么？为什么需要？（→ `.framelean-*.partial.*` + `OutputPreflightService`）
15. HDR 转 SDR 怎么做？为什么不能只靠 scale？（→ `docs/lessons.md`「HDR 转 SDR 需要同时校验滤镜能力」）
16. 硬件编码器怎么探测和降级？（→ `FfmpegEncoderCapabilities` + 平台优先级表）

### 数据与持久化
17. Drift schema 现在到 v29 了，迁移怎么保证幂等？（→ `docs/lessons.md`「Drift 迁移新增列要幂等」+ `_safeAddColumn`）
18. 什么入库、什么不入库？为什么 FFmpeg 日志不入库？（→ architecture.md「数据持久化边界」）
19. 主题首帧闪烁怎么解决的？为什么 `theme_prefs.json` 只是镜像？（→ `docs/lessons.md`「主题启动缓存只能作为首帧镜像」）

### 平台与发布
20. macOS Universal 2 怎么构建的？为什么不能拿 arm64 切片冒充 x64？（→ technology-stack.md macOS 段）
21. Windows 静默更新为什么不能只信退出码？（→ `docs/lessons.md` 第一条）
22. 自托管更新系统的客户端+服务端架构？（→ `docs/releases/v1.2.1/self-hosted-update-*.md`）

> 能答 18 题以上 → 可以开讲。答不上来的，去翻对应文件补课。**这一步是「充分了解项目」的硬指标。**

---

## 2. 讲解骨架（一场分享的结构）

```
开场（5min）
  ├── FrameLean 是什么（一句话 + 截图 + 演示一段压缩）
  ├── 为什么做这个（不手写 FFmpeg 命令也能处理本地媒体）
  └── 今天讲什么（架构 / 状态管理 / FFmpeg 工程化 / 踩坑）

第一幕：架构（10min）—— 看清骨架
  ├── 分层结构图（Clean Architecture）
  ├── 依赖方向约束 + 自动化测试守门
  ├── composition root 与 barrel 导出
  └── 一个任务从导入到完成的完整链路图

第二幕：状态管理（12min）—— Riverpod 在生产项目里怎么用
  ├── Provider 类型选择矩阵
  ├── main.dart 的 overrides（启动期依赖注入）
  ├── mediaTaskListProvider 深拆（AsyncNotifier + 依赖链 + 释放）
  └── 状态与 UI 解耦的设计

第三幕：FFmpeg 工程化（15min）—— 这是项目的硬核
  ├── 运行时定位与能力探测
  ├── 命令构造的分层拆解
  ├── 队列执行：受控并行 + 抢占 + 资源守卫
  ├── 进程控制：跨平台暂停/继续
  ├── partial 输出保护
  └── HDR/色彩处理边界

第四幕：踩坑与经验（8min）—— 真实项目的味道
  ├── 选 4-5 个最有代表性的坑讲（见第4部分）
  └── 每个坑讲：现象 → 根因 → 解法 → 沉淀的工程原则

收尾（5min）
  ├── 项目当前的边界（不做什么）
  ├── 后续方向
  └── Q&A
```

---

## 3. 关键代码切片 + 讲解要点

每个切片标注：**文件路径 / 讲什么 / 为什么值得讲 / 对应自检题**。

### 切片 1：分层架构一张图
- **素材**：`docs/develop/architecture.md` 的 mermaid 图 + 目录树
- **讲什么**：`features → application → domain`，`infrastructure` 实现，`app` 是 composition root。依赖方向单向，有测试守门。
- **为什么值得讲**：这是理解整个项目的前提。听者没建立这张图，后面所有代码切片都是散的。
- **对应自检**：题1、题2、题3。

### 切片 2：main.dart 的启动装配
- **素材**：`lib/main.dart`（35 行，极短）
- **讲什么**：
  - `window_manager` 初始化（桌面生命周期）
  - `LocalThemePreferencesCache` 快速读主题避免首帧闪烁（引出题19）
  - `ProviderScope(overrides: [...])`：为什么启动期要 override 数据库和初始设置？因为 `AppDatabase` 需要在外部创建以便 `ref.onDispose(database.close)` 管理生命周期，初始设置要带缓存主题。
- **为什么值得讲**：35 行浓缩了「桌面应用启动期要处理什么」。Riverpod 的 override 机制在这里第一次亮相。
- **对应自检**：题6、题19。

### 切片 3：Riverpod Provider 类型矩阵
- **素材**：`docs/develop/architecture.md`「Riverpod 组装方式」那张表（27 个 provider）
- **讲什么**：按类型分组讲——
  - `Provider<X>`（只读值/依赖注入）：`appDatabaseProvider`、`ffmpegProcessStarterProvider`、`fileRevealerProvider`
  - `FutureProvider`（异步一次性）：`appSettingsProvider`、`taskFolderListProvider`
  - `AsyncNotifierProvider`（异步有状态）：`mediaTaskListProvider`、`ffmpegRuntimeProvider`
  - `NotifierProvider`（同步有状态）：`workbenchPreviewProvider`
- **为什么值得讲**：直接回答「Riverpod 在生产项目里怎么用」——不是教科书讲 API，是真实项目里每种类型的选择逻辑。
- **对应自检**：题5。

### 切片 4：mediaTaskListProvider 深拆（核心切片）
- **素材**：`lib/features/workbench/providers/media_task_notifier.dart`
- **讲什么**：
  - 为什么是 `AsyncNotifierProvider`：任务列表要异步从 SQLite 加载，加载中/错误/数据三态
  - `build()` 里 `ref.watch` 串联了哪些依赖（settings、repository、ffmpeg runtime）
  - `ref.onDispose` 释放了什么（执行刷新 Timer）
  - 一个操作（如 `addTask`）怎么走：UI 调 `ref.read(mediaTaskListProvider.notifier).addTask()` → notifier 调 use case → use case 调 repository → state 更新
  - `state = AsyncData(...)` 后的副作用（如 `syncFfmpegQueueStatus()`）
- **为什么值得讲**：这是「状态管理 + 用例编排 + 副作用分离」三位一体的最佳样本。一个文件讲清 Riverpod 生产级用法。
- **对应自检**：题7、题8、题9。

### 切片 5：FFmpeg 命令构造的分层
- **素材**：`lib/infrastructure/services/ffmpeg_planning/` 目录 + `DefaultFfmpegCommandBuilder`
- **讲什么**：
  - 为什么不直接拼字符串：FFmpeg 命令复杂（视频/图片/音频/格式转换/目标体积/两遍压缩/HDR/透明视频），需要结构化规划
  - 拆了哪些 helper：output_path_builder / encoder_resolver / video_argument_builder / command_step_builder / command_log_hint_builder
  - 命令计划包含什么：`args` + `steps` + `outputPath` + `cleanupPathPrefixes` + `logHint`
  - 容器×编码兼容矩阵（MP4/MOV/MKV/WebM/AVI 各支持哪些编码）
- **为什么值得讲**：展示「如何把一个复杂的命令拼装问题工程化」。这是项目的技术深度所在。
- **对应自检**：题11。

### 切片 6：队列执行与受控并行
- **素材**：`DefaultFfmpegTaskQueueRunner` + `ExecutionResourceGuard`
- **讲什么**：
  - 三种启动模式：工作台连续队列 / 任务夹连续队列 / 单任务
  - 状态模型：idle / ready / running
  - 受控并行：用户设上限（1/2/3），资源守卫按 CPU/内存/任务类型降级
  - 视频任务独占性：同一时刻只允许一个视频 FFmpeg 进程
  - 抢占：单任务启动时若执行位满，暂停最早运行者，被抢占任务进 FIFO
- **为什么值得讲**：这是「生产级任务调度」的缩影，远超 demo 级别的「跑一个 ffmpeg」。
- **对应自检**：题12。

### 切片 7：跨平台进程控制
- **素材**：`FfmpegProcessController` + 两个实现 `SignalFfmpegProcessController` / `WindowsFfmpegProcessController`
- **讲什么**：
  - macOS/Linux：`SIGSTOP` / `SIGCONT` / `SIGTERM`
  - Windows：通过 runner method channel 调原生线程挂起/恢复
  - 为什么不能照搬：Windows 没有 Unix signal 语义，硬套会导致 UI 状态和进程不同步
  - 抽象的意义：application 层只依赖 `FfmpegProcessController` 接口，平台差异藏在 infrastructure
- **为什么值得讲**：典型的「跨平台差异处理」案例，体现分层架构的价值。
- **对应自检**：题13。

### 切片 8：partial 输出保护
- **素材**：`OutputPreflightService` + 执行器里的 250ms 监测
- **讲什么**：
  - 执行时先写 `.framelean-*.partial.*` 隐藏文件
  - 成功后原子发布到最终路径
  - 取消/失败/异常退出/启动恢复时清理 partial
  - 每 250ms 监测 partial 是否被外部删除，连续两次消失终止任务
- **为什么值得讲**：体现「不能信任外部环境」的工程意识。用户可能手动删文件、磁盘可能满、进程可能崩。
- **对应自检**：题14。

### 切片 9：HDR 与色彩处理边界
- **素材**：`docs/decisions/260613-video-color-hdr-sdr-boundary.md` + 命令构造相关代码
- **讲什么**：
  - SDR 源：优先保留 FFprobe 读到的色彩元数据，缺失时按分辨率推断
  - HDR10/HLG：`zscale + tonemap` 转 SDR BT.709，依赖 `libzimg`
  - Dolby Vision Profile 5：直接拒绝（避免变黑/偏紫/偏色）
  - 硬件编码器质量参数独立映射（CRF / NVENC CQ / QSV quality / AMF QP / VideoToolbox q:v）
- **为什么值得讲**：展示「在边界情况下做保守决策」的工程判断力。不是所有能转的都转，该拒绝就拒绝。
- **对应自检**：题15、题16。

### 切片 10：硬件编码器能力探测与降级
- **素材**：`FfmpegEncoderCapabilities` + `LocalFfmpegLocator`
- **讲什么**：
  - 启动时跑 `ffmpeg -hide_banner -encoders` 解析可用编码器
  - 平台自动优先级：macOS VideoToolbox 优先，Windows NVENC→QSV→AMF
  - 自动选择时硬件不可用回退软件
  - HDR/HVC1/10-bit 等高危源优先软件编码
  - 命令构造前校验能力（避免运行时才暴露 Unknown encoder）
- **为什么值得讲**：「运行时能力探测 + 优雅降级」是桌面应用集成外部工具的经典模式。
- **对应自检**：题10、题16。

---

## 4. 踩坑精选（第四幕讲 4-5 个）

从 `docs/lessons.md` 19 条里挑最有代表性的。挑选标准：① 听者能听懂 ② 有反直觉点 ③ 能沉淀出工程原则。

### 坑 1：Windows 静默覆盖安装不信任退出码
- **现象**：Inno Setup `/VERYSILENT` 安装因文件被占用静默失败，但退出码仍是 0。
- **根因**：进程列表消失后 Windows 文件锁可能仍持留数秒；退出前启动的子进程也可能持有句柄。
- **解法**：进程退出后再等 2-3 秒 → `taskkill /F` 强杀残留 → 解析安装日志 → 验证目标 exe 版本号。
- **工程原则**：**不要只信单一信号，要交叉验证**。退出码 0 ≠ 安装成功。
- **关联**：`tool/windows_updater_helper.dart`、`installer/windows/FrameLean.iss`。

### 坑 2：Riverpod provider 不伪装成 infrastructure
- **现象**：早期 provider 连接 application/infrastructure/features 时，放哪层都别扭。
- **根因**：它本质是 composition root，不是基础设施实现。
- **解法**：统一放 `app/providers/`，infrastructure 只留实现，application 只留抽象。
- **工程原则**：**架构角色要诚实**。装配不是实现，实现不是装配。
- **关联**：`docs/decisions/260614-clean-architecture-composition-root.md`。

### 坑 3：主题首帧闪烁
- **现象**：深色偏好用户启动时先看到浅色再闪到深色。
- **根因**：主题权威在 SQLite，但 DB 初始化有延迟，首帧来不及读。
- **解法**：`theme_prefs.json` 作首帧缓存镜像，启动后异步读 DB 自愈，DB 为准。
- **工程原则**：**缓存要有明确语义**。这个缓存只是镜像，不是 source of truth。
- **关联**：`docs/lessons.md` + `lib/main.dart` 的 `cachedTheme`。

### 坑 4：Windows 进程控制不能照搬 Unix signal
- **现象**：直接复用 `SIGSTOP/SIGCONT` 到 Windows，UI 状态和进程不同步，继续后进度卡住。
- **根因**：Windows 没有等价信号语义。
- **解法**：application 抽象 `FfmpegProcessController`，infrastructure 分平台实现（signal / method channel）。
- **工程原则**：**跨平台差异要靠抽象隔离，不是靠 if-else 堆**。
- **关联**：`SignalFfmpegProcessController` / `WindowsFfmpegProcessController`。

### 坑 5：ReorderableListView 要乐观更新
- **现象**：拖拽后先等 DB 持久化再更新 state，动画结束会短暂回到旧顺序再重建，预览图闪烁。
- **根因**：UI 数据没在同一帧同步更新。
- **解法**：先内存 state 计算重排结果并乐观更新 UI，再后台持久化，失败时刷新仓储恢复。
- **工程原则**：**UI 响应优先于数据一致性**，一致性可以后台追赶。
- **关联**：`docs/decisions/260607-task-reorder-optimistic-update.md`。

---

## 5. 可视化素材建议

讲的时候建议准备这几张图（可以用 mermaid 或手画）：

1. **分层架构图**（切片1用）—— 直接用 architecture.md 里的 mermaid。
2. **任务全链路流程图**（第一幕用）—— 导入→分析→配置→preflight→执行→观测→收尾→通知。
3. **Riverpod Provider 依赖图**（切片4用）—— 画 mediaTaskListProvider 依赖了哪些 provider，被哪些 UI 消费。
4. **队列执行状态机**（切片6用）—— idle/ready/running 三态 + 抢占/恢复箭头。
5. **平台差异对比表**（切片7用）—— macOS signal vs Windows method channel。

---

## 6. 常见追问与应答预案

听者大概率会问这些，提前想好答案：

| 追问 | 应答要点 |
|---|---|
| **为什么用 Riverpod 不用 Bloc/GetX/Provider？** | Riverpod 不依赖 BuildContext（可纯逻辑测试）、API 更现代（AsyncValue/Notifier）、3.x 主流写法稳定。Bloc 模板代码多，Provider 是上一代。 |
| **为什么用 Drift 不用 sqflite/isar/Hive？** | Drift 类型安全、schema 迁移管理成熟、SQL 可控。isar 当时生态不够，Hive 不适合关系型数据（任务夹关联）。 |
| **为什么不用 Flutter 原生 video_player 做预览？** | 预览是「压缩前后对比帧」，不是播放视频。用 FFmpeg 抽帧更可控，不依赖平台播放器。 |
| **FFmpeg 命令为什么不用 ffmpeg_kit_flutter？** | ffmpeg_kit 体积大、维护停滞、桌面端支持弱。直接调系统 FFmpeg 进程更灵活、可用户自定义路径、可探测编码器能力。 |
| **为什么支持 Linux/Web 目录但不发布？** | Flutter 工程模板自带。FFmpeg 本地进程路线不适用 Web；Linux 没有优先验证，不是当前目标。 |
| **任务队列为什么不用 isolate？** | FFmpeg 本身是独立进程，已隔离 CPU。主 isolate 负责协调和观测，够用。isolate 间通信反而增加复杂度。 |
| **Drift schema v29 了，迁移怎么管理？** | `_safeAddColumn` 幂等迁移、`PersistenceCompatibility` 保留历史兼容值、`CompressionModeMapper` 做旧值映射。 |
| **自托管更新为什么不上 App Store / Sparkle？** | macOS 没有开发者签名时不走 Sparkle；Windows 走 Inno Setup + helper.exe 静默覆盖。自托管完全可控、无审核。 |
| **NCM/QMC 解密为什么用 Dart 不用外部工具？** | NCM 算法简单（pointycastle 足够），本地解密无外部依赖。QMC 变体多，用外部 `qmc-decrypt` 更省心。 |
| **项目最难的部分是什么？** | FFmpeg 队列执行器（`DefaultFfmpegTaskQueueRunner`）—— 并行/抢占/资源守卫/进程控制/异常恢复/状态同步，是整个项目的硬核。 |

---

## 7. 录制/演讲节奏建议

- **每讲一个切片，遵循「是什么 → 为什么这么做 → 看代码 → 关联坑」四段式**。比如讲切片6 队列执行，先说「有受控并行」，再说「为什么不限死并行数」，再看 `ExecutionResourceGuard` 代码，最后关联「视频任务独占」的设计理由。
- **代码切片不要全文念**。挑 5-15 行核心，讲清「这段在做什么、为什么这么写」。其余让听者自己看仓库。
- **截图/录屏穿插**。讲架构时切到代码，讲队列执行时切到应用运行画面（拖入文件、看任务跑起来、暂停继续），讲踩坑时切到代码 + 日志。
- **留 2-3 个「钩子」**。讲到某处时说「这个坑我们最后讲」，制造期待感。比如 partial 保护、Windows 更新退出码。
- **不要试图讲全部**。FrameLean 有 260 个 dart 文件，讲不完。重点是让听者建立「这个项目的架构骨架和工程思维」，细节自己挖。

---

## 8. 后续动作

- [ ] 过一遍第1部分自检清单，标记答不上来的题，去翻对应文件。
- [ ] 决定第4部分踩坑讲哪 4-5 个（我挑的 5 个是建议，你可换）。
- [ ] 决定要不要我帮你把第3部分的代码切片**逐个写成讲解脚本**（每个切片一段口语化讲稿，可直接照念）。
- [ ] 决定要不要我帮你画第5部分的可视化图（mermaid 或 SVG）。
- [ ] 如果要录视频，建议先对着自检清单 + 骨架 dry-run 一遍，卡壳的地方就是需要补课的地方。
