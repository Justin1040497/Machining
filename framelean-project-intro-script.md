# FrameLean 项目介绍 — 讲解脚本（可直接照念）

> 这是给**你本人**的逐题讲解脚本。每道题都按「口语化 + 可照念」的方式写，你可以直接对着镜头/听众念。
>
> 建议总时长：15-20 分钟。
>
> 每道题后面标注了【关键数据】和【对应文件】，方便你在被追问时展开。

---

## Q1：这个软件是干嘛的？

### 口语脚本

FrameLean，中文名叫「帧轻」，是一个**本地桌面媒体压缩与格式处理工具**。

一句话概括：**让你不用手写 FFmpeg 命令，就能在电脑上处理本地视频、图片和音频。**

它基于 Flutter 构建，支持 macOS 和 Windows 两个平台。核心功能就是——你把媒体文件拖进去，它会自动分析文件信息、给你推荐压缩方案或者让你自己调参数，然后调用本地的 FFmpeg 来执行处理任务。

具体来说它能做什么：

- **19 种视频格式**：MP4、MOV、MKV、AVI、WebM 这些主流的都能导入和转换输出
- **13 种图片格式**：JPG、PNG、WebP、HEIC 等等
- **20 种音频格式**：MP3、WAV、FLAC、AAC、Opus，甚至还能解密网易云音乐 NCM 这种专有格式

视频这块功能最完整：你可以选推荐方案——比如「微信发送」「清晰优先」「体积优先」，也可以自定义目标体积、编码器（H.264、H.265、VP9、AV1）、分辨率、输出容器。它会帮你构造好 FFmpeg 命令并执行，处理完通知你。

图片和音频也进入了同一套任务模型：导入、分析、配置、批量管理、完成展示，流程一致。

另外还有一些工程化的细节：
- **受控并行队列**：可以同时跑多个任务，但有上限控制，不会把电脑拖垮
- **任务夹**：可以把相关任务分组，批量操作
- **自托管更新**：不用上应用商店，自己部署更新服务
- **深浅主题切换**
- **通知中心**

### 关键数据

| 维度 | 数据 |
|---|---|
| 当前版本 | v1.2.1+5 |
| 平台 | macOS 10.15+ (Universal 2) / Windows x64 |
| 技术栈 | Flutter + Dart ^3.11.0 + Riverpod 3.x + Drift v29 + FFmpeg 7.1.1 |
| 视频编码器支持 | 软件编码(libx264/libx265/libvpx-vp9/libsvtav1/prores_ks/mpeg4/mjpeg) + 硬件加速(VideoToolbox/NVENC/QSV/AMF) |
| 输出容器 | MP4/MOV/MKV/WebM/AVI |
| 许可证 | GPLv3+ |

### 对应文件
- `README.md` 第8-60行（产品定义与功能清单）
- `docs/develop/architecture.md`（架构全景）
- `pubspec.yaml`（版本号与技术依赖）

---

## Q2：为什么有同款的视频压缩软件还要做一个这样的软件？

### 口语脚本

这个问题很好，也是我最常被问到的。市面上确实有不少同类产品，最知名的就是 HandBrake，中文昵称「大菠萝」。我也做过详细的竞品对比分析。

但 FrameLean 和它们**品类定位不同**。

HandBrake 是一个**纯视频转码工具**，它的强项在于字幕处理、视频滤镜、章节标记这些专业转码能力。但它只做视频，不支持图片压缩和音频独立处理，也不支持像 NCM 解密这种国内特有的需求。

而 FrameLean 定位的是**媒体压缩套件**——视频+图片+音频三位一体。这是第一个差异化点。

第二个差异化点，是**任务模型的设计**。HandBrake 的 Queue 基本是串行的，一个接一个跑。FrameLean 有**受控并行**——你可以设同时跑 1 到 3 个任务；有**任务夹**可以把任务分组管理；有**插队抢占**——单任务启动时如果队列满了会暂停最早的那个让位；还有**源文件丢失检测**和**重启恢复**。这些是面向「批量处理工作流」的设计，不是「打开一个文件转一下」的工具思维。

第三个点，是**技术路线的选择**。HandBrake 用 C/C++ 写 GUI，维护成本高。我用 Flutter 写，跨平台一套代码同时出 macOS 和 Windows。FFmpeg 不是通过 ffmpeg_kit 这类 Flutter 插件集成，而是**直接调用系统 FFmpeg 进程**——这样更灵活、可用户自定义 FFmpeg 路径、可探测可用编码器能力做降级。这个选择让 FrameLean 在硬件编码器支持和运行时适配上有更大的自由度。

第四个点，是一些**国内场景的特殊支持**。比如网易云音乐的 NCM 格式用 Dart 本地解密，QQ 音乐的 MGG/MFLAC 通过 qmc-decrypt 接入，HDR 转 SDR 自动处理 Dolby Vision 风险拦截——这些都是面向中文用户实际需求的。

当然也要诚实地说，HandBrake 在某些方面远超 FrameLean：字幕处理、DVD/蓝光光盘源输入、两遍编码、成熟预设系统、十余年的社区积累。FrameLean 在图片压缩、音频独立处理、并行队列、目标体积反推、ProRes 输出、HDR→SDR 自托管更新这些方面有自己的优势。

所以不是「重复造轮子」，而是在一个不同的定位上做了取舍和聚焦。

### 关键竞品对比

| 能力 | HandBrake | FrameLean |
|---|---|---|
| 视频 | ✅ 完整 | ✅ 完整（压缩链路） |
| 图片 | ❌ | ✅ JPEG/PNG/WebP/BMP/TIFF/GIF |
| 音频 | ❌ Passthru | ✅ MP3/WAV/FLAC/AAC/Opus 等 |
| 批量队列 | 串行 | 受控并行 + 任务夹 + 抢占 |
| 目标体积反推 | 无 | 有（比例滑杆） |
| ProRes 输出 | 无 | ✅ |
| HDR→SDR | 有限 | zscale+tonemap 自动 |
| 字幕/DVD/蓝光 | ✅ 强 | 不做 |
| 两遍编码 | ✅ | CRF 模式为主 |
| 开源协议 | GPL v2 | GPL v3+ |
| GUI 技术 | C/C++ (原生) | Flutter (跨平台) |

### 对应文件
- `competitive-analysis-handbrake.md`（完整竞品对比报告）
- `README.md` 第46-49行（NCM/QMC 支持）
- `docs/lessons.md`「HDR 转 SDR 需要同时校验滤镜能力」

---

## Q3：这个项目使用了哪些 Skills？

### 口语脚本

这里的 Skills 不是指技术栈，而是指**项目级 AI Skill 工作流体系**——放在 `.agents/skills/` 目录下的一组可复用 AI 协作流程定义。

为什么要做这件事？因为这个项目是我和 AI 助手协作开发的。协作多了就会发现一个痛点：**每次让 AI 干活，都要重复讲一遍项目背景、约束、流程规矩**。AI 自由发挥很容易跑偏——改了不该改的文件、跳过测试、忘记更新文档、自己往 main 上提交。

所以我做了一件事：把「AI 应该怎么在这个项目里干活」固化成 9 个 skill，每个 skill 负责开发流程中的一个明确阶段。AI 助手开工前先读对应的 skill，就知道这一步该做什么、不该做什么、产物放哪、要不要等用户确认。

### 一、整体设计：1 个路由器 + 6 步开发链 + 1 个发布 + 1 个元 skill

**先说路由器——`framelean-workflow`**。

这是入口 skill。当用户不确定该用哪个 skill、或者一句话横跨多个阶段时，先调它。它的作用很轻——读一下用户的意图，路由到最合适的那一个具体 skill。它不干活，只指路。这避免了「9 个 skill 用户记不住该用哪个」的问题。

**再说 6 步完整开发链**。这是核心，对应一个功能从需求到上线的完整生命周期：

```
framelean-requirement-pool   ← 第1步：需求池
        ↓
framelean-feature-analysis   ← 第2步：功能分析
        ↓
framelean-feature-plan       ← 第3步：实施计划
        ↓
framelean-implementation     ← 第4步：编码实现
        ↓
framelean-validation         ← 第5步：验证审查
        ↓
framelean-delivery           ← 第6步：交付收尾
```

每一步的职责边界很清晰：

**第1步 `framelean-requirement-pool`（需求池）**：只做一件事——和用户讨论候选需求，确认后往 `docs/work/backlog.md` 里加一行。它不设计、不拆任务、不写代码。产物就是 backlog 表里的一行，字段是 ID/模块/优先级/状态/候选事项/下一步/来源。

**第2步 `framelean-feature-analysis`（功能分析）**：把需求变成结构化的功能分析。它强制输出五个部分——交互链（用户故事+操作路径+mermaid 流程图）、逻辑树（事件流表+状态流转表）、功能定位（哪个层级、是否已有、证据）、边界和依赖（接口定义方/消费方/风险）、结论（开发顺序建议+复杂度集中点+暂不实现理由）。如果用户没指定新需求，它会主动从 backlog 推荐 2-3 个未完成项。默认输出内联，不落盘——只有用户确认或要进入 backlog 时才写。

**第3步 `framelean-feature-plan`（实施计划）**：把已确认的分析变成可执行计划。强制输出九个部分——结论、现状证据表、方案比较表（按产品影响/可维护性/可测试性/平台风险/迁移成本对比）、设计说明、执行任务表（顺序/任务/主要文件/依赖/状态）、验证计划表、分支建议（2-4 个，用 feature/*/fix/*/chore/* 等前缀）、暂不实现、可能需要更新的 docs。计划默认内联，需要保留时写到 `.workspace/plans/YYMMDD-feature-slug.md`——注意是 `.workspace/` 不是 `docs/`，因为计划是临时的，确认后才进 docs。

**第4步 `framelean-implementation`（编码实现）**：这一步才真正写代码。但它有严格的 scope 规则——不添加未确认功能、不做大重构、不产生格式化噪音、不 stage/commit/push/revert/delete 无关用户改动。如果发现确认的计划变得不可行或有风险，必须停下来解释冲突，而不是擅自改 scope。架构规则也写死在里面：features→application→domain，infrastructure 实现 application 抽象，domain 保持零外部依赖。

**第5步 `framelean-validation`（验证审查）**：有三种模式——Plan 模式（实现前写验证计划）、Review 模式（实现后审 diff）、Run 模式（跑检查）。审查重点写得很具体：业务边界越界、架构边界违规、变更行为缺测试、脚本/打包/CI/运行时路径/发布假设被破坏、文档过时、误带无关用户改动。默认检查命令也写死了：`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test`。

**第6步 `framelean-delivery`（交付收尾）**：校准项目事实文档 + 产出 commit 信息和 PR description。它会扫描一堆当前事实文档（CONTEXT/README/AGENTS/CHANGELOG/docs/*），用 `rg` 找过时的路径、删除的 skill 名、变化的命令。还有一个**打包新鲜度检查**——对 release/CI/installer/update/signing 相关变更强制检查 GitHub Actions、发布脚本、macOS Info.plist、Windows installer、签名工具是否一致。最后产出 Markdown 的 commit 信息和 PR description，但不执行 git add/commit/push，除非用户明确要求。

**然后是发布——`framelean-release`**。它独立于交付链，只在用户指定版本号时使用。扫描自上个 tag 以来的 Git 历史 + 当前 docs，草拟 release notes，确认后写到 `docs/releases/vX.Y.Z/release.md`。它也有打包新鲜度门禁——发布前必须核对当前打包源码和发布声明是否一致，发现漂移就停下来问是先修还是记为已知风险。

**最后是元 skill——`framelean-skill-create`**。这是「管理 skill 的 skill」。创建/更新/合并/删除/重构这 9 个 skill 自身时用它。它调用系统的 skill-creator 脚本（init_skill.py 创建、quick_validate.py 校验），并强制 FrameLean 项目规则：skill 只能放 `.agents/skills/`、命名必须 `framelean-` 前缀、不建 skill 级 README、增删改后同步更新 README.md 和 workflow 路由表。

### 二、共享预读协议：4 级递进读取

9 个 skill 共享一套预读协议，避免 AI 每次都全量读项目浪费上下文。分 4 级按需递进：

- **Level 1 项目事实**（默认先读）：AGENTS.md / CONTEXT.md / CHANGELOG.md / docs/README.md / docs/work/active.md / backlog.md / decisions.md
- **Level 2 领域事实**（按任务选读）：相关版本的 release 文档、相关决策、lessons.md、architecture.md、data-model.md、technology-stack.md、test-plan.md、workflow.md、reference/*
- **Level 3 代码事实**（只有分析/实现/验证时才读）：先用 `rg` 搜模块名/类名/文件名/功能关键词，只打开命中的源码、测试、脚本、配置。明确写了「不为了解项目全量读取 lib/、test/、scripts/」
- **Level 4 Git 事实**（只有 validation/delivery/release 或用户明确要求时读）：git status / branch / diff / log / tag

这个分级的关键思想是：**上下文是稀缺资源，按需读取比全量读取更高效**。

### 三、两个目录约定：`.workspace/` vs `docs/`

这是整个 skill 体系里很重要的边界：

- **`.workspace/`**：临时计划、release 草稿。`plans/YYMMDD-feature-slug.md` 和 `release-drafts/vX.Y.Z.md`。**不进版本库**。讨论中的、未确认的东西放这里。
- **`docs/`**：当前仍有效的项目事实、版本事实、决策、经验、工作池。**进版本库**。只有确认后的稳定事实才能从 `.workspace/` 迁到 `docs/`，由 delivery 或 release skill 完成。

明确禁止创建 `docs/archive/`、`docs/features/`、`docs/plans/`、`docs/product/roadmap.md`——避免文档目录膨胀。

### 四、Gate 机制：不让 AI 自由发挥

整套 skill 体系有一个贯穿始终的设计——**每一步都要用户确认才能往下走**。具体写在 workflow 路由器的 Gates 段：

- 不从讨论进入实现，直到用户明确接受需求/分析/计划（除非用户要求端到端执行）
- 不 stage/commit/push/tag/创建 PR/发布 release，除非用户明确要求
- `.workspace/` 只放临时计划，`docs/` 只放确认事实

这个设计的意义是：**AI 是协作者不是决策者**。它可以分析、可以建议、可以写代码、可以跑测试，但「要不要做」「要不要提交」「要不要发布」这些决策权始终在人手里。

### 五、为什么这么做？

总结一下这套 skill 体系的价值：

1. **可复用**：每次 AI 协作不用重讲项目背景和规矩，读 skill 就行
2. **可约束**：AI 不能自由发挥，scope/架构/git 操作都有明确边界
3. **可追溯**：每一步有明确产物（backlog 行/分析文档/计划文件/代码/验证结果/commit 文案/release 文档）
4. **可演化**：skill 本身用 `framelean-skill-create` 管理，可以增删合并重构
5. **上下文高效**：4 级递进读取避免浪费 token

这套体系本身就是项目工程化的一部分——它解决的是「人机协作开发」这个新问题。传统项目没有这个问题，因为人是直接写代码的。但当一个项目的代码有相当比例是 AI 协作产出时，**怎么让 AI 干活有规矩**就变成了一个真实工程问题。FrameLean 的 `.agents/skills/` 就是对这个问题的回答。

### 关键数据

| 维度 | 数据 |
|---|---|
| Skill 总数 | 9 个（1 路由器 + 6 步开发链 + 1 发布 + 1 元 skill） |
| 目录位置 | `.agents/skills/framelean-*` |
| 命名规则 | 必须 `framelean-` 前缀，小写连字符 |
| 共享预读 | 4 级递进（项目事实 → 领域事实 → 代码事实 → Git 事实） |
| 临时目录 | `.workspace/plans/` 和 `.workspace/release-drafts/`（不进版本库） |
| 事实目录 | `docs/`（进版本库，仅确认后稳定事实） |
| Gate 机制 | 每步需用户确认才往下走；不擅自 git 操作 |
| 元 skill | `framelean-skill-create` 管理 skill 自身 |

### 对应文件
- `.agents/skills/README.md`（项目级 skill 规则 + 共享预读协议 + 路由表 + 推荐流程）
- `.agents/skills/framelean-workflow/SKILL.md`（路由器 + Gates 机制）
- `.agents/skills/framelean-requirement-pool/SKILL.md`（需求池）
- `.agents/skills/framelean-feature-analysis/SKILL.md`（功能分析，含输出模板）
- `.agents/skills/framelean-feature-plan/SKILL.md`（实施计划，含 9 段输出模板）
- `.agents/skills/framelean-implementation/SKILL.md`（编码实现，scope/架构规则）
- `.agents/skills/framelean-validation/SKILL.md`（验证，三模式+默认检查命令）
- `.agents/skills/framelean-delivery/SKILL.md`（交付收尾，含打包新鲜度检查）
- `.agents/skills/framelean-release/SKILL.md`（发布文档，含打包新鲜度门禁）
- `.agents/skills/framelean-skill-create/SKILL.md`（元 skill，管理 skill 自身）
- `AGENTS.md`（项目入口，引用 skill 路由）

---

## Q4：这个项目的架构是什么样的，介绍一下？

### 口语脚本

FrameLean 采用的是**接近 Clean Architecture 的分层结构**。我说是「接近」而不是「严格」，因为在实际项目中做了一些务实的调整。

整个项目分成五层，从外到内是：

**最外层是 features（功能层）**：目前只有一个 feature 就是 workbench 工作台。这一层包含页面（WorkbenchPage）、弹窗、覆盖层、表单控件、任务列表组件。它是纯粹的 UI，不应该包含任何业务逻辑。

**往里一层是 app（应用层）**：这是 composition root，也就是「组装」的地方。路由配置在这里，全局 Provider 也在这里——`app/providers/` 目录下的所有 Riverpod Provider 都在这一层。它的职责是把内层的接口和外层的实现「粘」起来。比如 TaskRepository 接口在 application 层定义，SQLite 实现在 infrastructure 层，而把它们装配成一个 Provider 就在 app 层完成。

**再往里是 application（应用层）**：注意这个名字容易混淆——这里的 application 不是指「整个应用」，而是 Clean Architecture 中的「应用逻辑层」。这一层放着 Use Case（用例），比如 AddTaskUseCase、CompressMediaTaskUseCase，还放着仓储接口（Repository interface）、命令规划的抽象、执行服务的抽象。这一层的代码不依赖任何 UI 框架，也不依赖具体的数据库实现或文件系统——它只定义「做什么」，不关心「怎么做」。

**再往里是 infrastructure（基础设施层）**：这是所有「怎么做」的实现。Drift 数据库在这里、SQLite 具体建表查表在这里、FFmpeg/FFprobe 进程调用在这里、本地文件操作在这里、平台特定的实现（比如 macOS 的 signal 控制 vs Windows 的 method channel）也在这里。infrastructure 实现了 application 层定义的所有接口。

**最中心是 domain（领域层）**：实体（Entity）、枚举、值对象。MediaTask、TaskFolder、CompressionMode、MediaKind 这些纯数据结构和业务规则。这一层没有任何外部依赖——不依赖 Flutter，不依赖数据库，不依赖 FFmpeg。它是最稳定的一层，变动最少。

依赖方向是**单向的**：features → app → application → domain，加上 infrastructure → application（实现接口）。也就是说，外层可以依赖内层，但内层永远不能反向依赖外层。features 不能直接访问 infrastructure，必须经过 application 层的中转。

为了守住这条规则，我写了一个自动化测试叫 `architecture_dependencies_test.dart`，每次跑测试都会检查 import 方向有没有违规。如果有人不小心在 domain 里 import 了 Flutter 包，或者在 features 里直接用了 Drift 的具体实现，测试就会挂掉。靠目录命名和 code review 是守不住的，必须有机器守门。

还有一个重要的设计决策是 **barrel 文件（library.dart）导出机制**。每一层的公开 API 都通过一个 `library.dart` 文件统一导出，跨层导入只能走 barrel 文件，不能直接 import 到内部文件。这样做的好处是：层的边界清晰、重构内部文件不影响外层、IDE 能给出准确的补全提示。

让我用一个具体例子串一遍整个架构的调用链：

用户拖入一个视频文件 → **features** 的 WorkbenchPage 收到拖拽事件 → 调 **app** 层的 Provider 拿到 TaskRepository → **application** 层的 AddTaskUseCase 校验媒体类型、创建 MediaTask 实体（这个实体定义在 **domain** 层）→ 调 Repository 接口的 save 方法 → **infrastructure** 层的 DriftRepository 把数据写入 SQLite。整个过程每一层的职责都很清楚。

### 关键数据

```
lib/
├── app/                    ← composition root: 路由、Provider 装配、全局配置
│   ├── providers/          ← 27 个 Riverpod Provider
│   └── ...
├── domain/                 ← 纯实体、枚举、值对象（零外部依赖）
│   ├── entities/
│   └── library.dart        ← barrel 导出
├── application/            ← Use Cases、仓储接口、命令/执行抽象
│   ├── use_cases/
│   ├── ports/
│   └── library.dart
├── infrastructure/         ← Drift DB、仓储实现、FFmpeg/FFprobe、文件系统、平台实现
│   ├── database/
│   ├── services/
│   └── library.dart
└── features/
    └── workbench/          ← 页面、弹窗、列表组件（纯 UI）
```

### 对应文件
- `docs/develop/architecture.md`（完整架构文档，含 mermaid 图和依赖规则表）
- `test/architecture_dependencies_test.dart`（自动化依赖守门）
- `docs/decisions/260623-library-barrel-import-architecture.md`（barrel 文件决策）
- `docs/decisions/260614-clean-architecture-composition-root.md`（composition root 决策）

---

## Q5：为什么不使用 MVVM 架构？

### 口语脚本

这是个很好的问题。MVVM——Model-View-ViewModel——在 Flutter 社区非常流行，尤其是搭配 Provider 或 GetX 使用的时候。但我没有选择 MVVM，原因是 **MVVM 和我的项目需求之间存在几个根本性的不匹配**。

**第一，MVVM 的 ViewModel 天然耦合 View 的生命周期。** ViewModel 通常是为特定 Page 或 Widget 服务的，它的状态和 View 的展示是一一对应的。但我的项目中，大量状态是**跨页面共享的全局单例**——任务列表在工作台页要用、设置页可能要读统计、通知中心要知道任务完成事件、执行器后台跑着不需要任何 View。这种「全局状态 + 多消费者」的模式，用 ViewModel 来建模会很别扭——你要么把它做成全局单例（那就不叫 ViewModel 了），要么在每个页面各持有一份（那就有了同步问题）。Riverpod 的 Provider 天生就是全局单例且自动处理多消费者订阅，更适合这种模式。

**第二，MVVM 的三层划分对我的项目来说粒度太粗。** 我的 Clean Architecture 有五层，每一层都有明确的单一职责：Domain 定义业务实体、Application 定义用例接口、Infrastructure 实现底层细节、Features 只管 UI、App 做装配。MVVM 的 Model 对应什么？如果 Model = Domain + Infrastructure 那就太厚了；ViewModel = Application？那 ViewModel 会变得巨大——它既要编排用例又要管理状态还要协调多个 Repository。View = Features？那 Features 里不能有任何状态管理逻辑，所有交互都得绕回 ViewModel，对于桌面应用那种复杂的拖拽排序、右键菜单、键盘快捷键来说，这种全量回传会让代码变得很啰嗦。

**第三，MVVM 没有自然解决「依赖注入」的位置问题。** 在典型的 Flutter MVVM 里，ViewModel 往往在 State.initState 里通过 Provider.of 或者 GetIt.instance 来获取依赖。这意味着 DI 和 View 的生命周期绑定了。但在我的项目中，依赖关系很复杂——TaskRepository 依赖 AppDatabase，AppDatabase 需要在启动时创建并在应用退出时关闭（ref.onDispose），FFmpeg 运行时需要在启动前探测能力。这些「应用级生命周期」的东西不属于任何一个 ViewModel，它们属于 Composition Root。Riverpod 的 ProviderScope 正好提供了这个位置——在 main.dart 的顶层声明所有依赖关系，任何地方都可以通过 ref 读取，不绑定任何 Widget 的生命周期。

**第四，MVVM 对「异步有状态」的支持不够优雅。** 我的任务列表是一个经典的「异步加载 + 可变状态」复合体：应用启动时要异步从 SQLite 加载（Future），加载过程中有 loading/error/data 三态，加载完后用户可以增删改（mutable state），改完要持久化回库。在 MVVM 里，你通常会在 ViewModel 里放一个 `_loading` 布尔、一个 `_error` 字符串、一个 `_list` 列表，然后用 notifyListeners 或者 StreamController 通知 View 更新。这在简单场景没问题，但一旦复杂度上来——比如任务列表还依赖设置变化（设置变了列表要重载）、还依赖 FFmpeg 运行时状态（运行时变了任务进度要更新）——ViewModel 就会变成一堆字段和手动协调逻辑。Riverpod 的 AsyncNotifier 把「异步加载 + 可变状态 + 依赖追踪 + 三态渲染」封装成了一个原语，build() 方法里写 ref.watch 声明依赖，框架自动处理失效重算。

**第五，MVVM 的测试方式不如 Riverpod 直接。** 测试 MVVM ViewModel 你通常需要 WidgetTester 搭建 Widget 树、塞进 ProviderScope、find.byType 拿到 Widget 再读 ViewModel。测试的是「View 能正确拿到 ViewModel 的数据」。但很多时候我想测试的是纯逻辑：「给一个空列表，添加三个任务，删除中间那个，断言剩下两个且顺序对」。这种测试用 Riverpod 的 ProviderContainer 就能写——不需要任何 Widget，不需要 BuildContext，纯 Dart 测试，速度快十倍。对于一个以 FFmpeg 命令构造和队列调度为核心的项目来说，纯逻辑测试的价值远高于 UI 测试。

**总结一下**：不是说 MVVM 不好——它在很多场景下是非常合适的，特别是那些「一页面对应一个 ViewModel、状态主要服务于 UI 展示」的应用。但 FrameLean 是一个**以全局状态管理和后台任务处理为核心的桌面工具**，它的状态跨越页面、依赖关系复杂、需要大量纯逻辑测试。Clean Architecture + Riverpod 的组合在这些维度上更匹配。

如果你非要类比的话，Riverpod 的 Provider 其实有点像 MVVM 的 ViewModel，但它是**解耦了 View 生命周期的全局 ViewModel**，并且自带依赖注入、派生状态、失效管理这些能力。你可以把它理解成「MVVM 的 ViewModel + Redux 的 Store + DI 容器」三合一。

### 对应文件
- `docs/develop/architecture.md`（架构选择理由）
- `lib/features/workbench/providers/media_task_notifier.dart`（AsyncNotifier 实例——替代 ViewModel 的地方）
- `lib/app/providers/`（Composition Root —— 替代 DI 容器的地方）
- `test/` 目录下的纯逻辑测试（无需 WidgetTester 的测试实例）

---

## Q6：项目的核心部分是哪块，讲一下技术实现？

### 口语脚本

如果说 FrameLean 有一个「心脏」的话，那就是 **FFmpeg 任务队列执行器**——代码里的 `DefaultFfmpegTaskQueueRunner`。

为什么说它是核心？因为整个应用的其他部分——UI、数据库、状态管理、设置——最终都是为了**把一个媒体文件送到这里来处理**。用户拖入文件、分析、配置参数，最后一步都是「提交到队列执行」。执行器的质量直接决定了用户体验：任务能不能顺利跑完？进度准不准？卡住了怎么办？并行会不会把电脑搞崩？

我来拆开讲它的技术实现。

### 一、整体架构：受控并行 + 状态机

执行器的核心是一个状态机，只有三个合法状态：

- **idle**：空闲，没有任务在跑
- **ready**：就绪，队列里有待执行任务但还没启动
- **running**：运行中，至少有一个任务正在执行

三种启动模式：
1. **工作台连续队列**：底部点「全部开始」，按总列表顺序连续执行
2. **任务夹连续队列**：某个任务夹的点「夹内开始」，只执行夹内的
3. **单任务开始**：某个任务的「单独开始」，可以**插队**——如果当前执行位满了，会暂停最早运行的那个任务让它让位

关键点是「**受控并行**」。用户可以在设置里设并行上限：1、2 或 3。不是说你想跑多少就跑多少——执行器有一个 **ExecutionResourceGuard（资源守卫）**，它在每次尝试启动新任务之前会做资源预算检查：

- 当前正在运行的 FFmpeg 进程数是否已达上限？
- CPU 核心数是否足够？
- 内存余量够不够？
- 如果是视频任务，同一时刻**只允许一个视频 FFmpeg 进程**在跑（视频任务独占性）

如果资源不够，不会硬上，而是降低并发度或者排队等待。这个设计避免了用户设了并行 3 但电脑只有 4 核结果卡成PPT的情况。

### 二、单个任务的完整执行链路

一个任务从进入队列到完成，要经过这些步骤：

**第一步：Preflight（起飞前检查）**
在真正启动 FFmpeg 之前，先做输出预检。OutputPreflightService 会检查：
- 输出目录是否存在、是否有写入权限
- 输出文件名是否会和已有文件冲突
- 磁盘空间是否充足

检查通过后，创建一个**隐藏的 partial 文件**——比如目标输出叫 `output.mp4`，实际先写成 `.framelean-output.mp4.partial.mp4`。这个 partial 文件对用户是不可见的。

**第二步：命令构造**
这是另一个复杂的模块。DefaultFfmpegCommandBuilder 负责「根据任务配置生成完整的 FFmpeg 命令参数数组」。它不是一个函数干到底，而是拆成了 6 个 helper 协作：

- output_path_builder：决定输出路径和文件名（支持 `{source}` `{date}` `{codec}` 等变量模板）
- encoder_resolver：根据用户选择的编码和平台能力，决定最终用哪个编码器（比如用户选 H.264 自动，macOS 上会用 VideoToolbox.h264，没有的话降级 libx264）
- video_argument_builder：构造视频相关参数（码率、分辨率、preset、CRF、像素格式等）
- command_step_builder：有些任务需要多步（比如 two-pass 编码），这里负责把一步或多步组织起来
- audio_argument_builder / image_argument_builder：音视频各自的参数构造
- command_log_hint_builder：生成人类可读的命令摘要用于日志显示

特别值得一提的是 **容器×编码兼容矩阵**：MP4 支持哪些编码、MOV 支持哪些、MKV 支持哪些、WebM 支持哪些——每种容器都有白名单，用户选了不支持的组合会提前报错，不会等到 FFmpeg 启动后才失败。

**第三步：进程启动与观测**

命令构造好了之后，由 FfmpegProcessStarter 启动一个系统进程。然后 FfmpegProcessObserver 开始观测这个进程——它做的事情是：

- 从 stdout/stderr 实时读取 FFmpeg 的输出
- 解析其中的 **progress line**（FFmpeg 固定格式的进度行，包含 `out_time_ms`、`speed`、`bitrate`、`fps` 等字段）
- 把解析出的进度回调给执行器，执行器更新任务状态
- 同时监听进程的 exitCode

这里有个很重要的设计：**日志写到临时文件不入库**。FFmpeg 的 stderr 日志量很大（尤其视频编码），存 SQLite 会撑爆而且没必要。所以执行日志写在系统临时目录的一个 `.log` 文件里，任务完成后可以通过任务详情查看原始日志，但不会持久化到数据库。

**第四步：Stall 检测（防死锁）**

FFmpeg 进程有时候会「假死」——进程还在，但不输出任何东西。常见原因：网络盘 IO 卡住、硬件编码器死锁、磁盘满导致写入阻塞。

执行器内置了一个 **stall detection** 机制：启动一个定时器，每隔几秒检查一次上次收到 stdout/stderr 数据的时间。如果超过阈值（默认 60 秒）没有任何活动，判定为 stalled，主动 kill 进程并标记任务失败。这样不会出现任务永远卡在 running 的情况。

**第五步：进程控制（暂停/继续/终止）**

这是跨平台差异最大的部分：

- **macOS/Linux**：使用 Unix signal——`SIGSTOP` 冻结进程、`SIGCONT` 恢复、`SIGTERM` 终止。这是操作系统级别的进程控制，非常可靠。
- **Windows**：没有等价的 signal 语义。如果强行套用会导致 UI 状态和底层进程不同步——比如 UI 显示「已继续」但进程其实没恢复。解决方案是在 application 层抽象了一个 `FfmpegProcessController` 接口，定义 pause/resume/terminate 三个方法。然后 infrastructure 层有两个实现：macOS 用 SignalFfmpegProcessController（发 signal），Windows 用 WindowsFfmpegProcessController（通过 runner 的 method channel 调原生线程挂起/恢复）。UI 层只依赖接口，完全不知道底层差异。

**第六步：完成或失败的处理**

任务正常完成时：
- 从 partial 文件**原子发布**到最终路径（重命名，用户可见）
- 更新任务状态为 completed
- 触发通知（临时通知 + 通知中心记录）
- 检查队列里还有没有下一个任务，有的话继续启动

任务失败或取消时：
- 清理未发布的 partial 文件（删除隐藏文件）
- 更新任务状态为 failed/cancelled
- 记录错误信息（友好化后的文案 + 原始 stderr 供查看日志时用）
- 对于硬件编码器相关的失败，有一个 **auto-retry** 机制：如果是 VT session 失效（常见于笔记本睡眠唤醒后），自动删除残缺输出、重新从头启动该 step，最多重试一次

### 三、异常恢复

除了正常的成功/失败路径，执行器还要处理几种异常情况：

**应用崩溃恢复**：应用非正常退出（杀进程、系统崩溃）后再次启动，执行器会扫描 SQLite 中的任务状态。发现处于 running 状态的任务（说明上次没跑完）标记为需要恢复。partial 文件还在的话说明上次跑到一半，会被清理掉。

**源文件丢失**：执行前或执行中发现源文件不存在或被移动，标记为 source_missing，提示用户重新指定。

**FFmpeg 运行时缺失**：启动时找不到 ffmpeg 或 ffprobe，整个执行链路不可用，在设置页显示警告引导用户配置路径。

### 总结

执行器这个模块大概占了项目中最复杂的代码量。它的设计原则是：

1. **不信任外部环境**——partial 文件、stall 检测、源文件校验，全是防御性设计
2. **跨平台差异隔离**——进程控制抽象为接口，业务逻辑不感知平台
3. **资源受控**——不假设用户的机器无限强大，做预算检查和自动降级
4. **用户可感知**——进度实时更新、失败有友好文案、通知及时送达

这就是 FrameLean 的核心技术实现。其他的——UI 怎么画、设置怎么存、主题怎么切——相对都是围绕这个核心服务的。

### 关键代码位置

| 模块 | 文件 | 行数级 |
|---|---|---|
| 队列执行器 | `lib/application/services/execution/ffmpeg_task_queue_runner.dart` | ~1400 行（最大文件） |
| 资源守卫 | `lib/application/services/execution/local_execution_resource_guard.dart` | ~100 行 |
| 命令构造 | `lib/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart` | ~500 行 |
| 命令 helpers | `lib/infrastructure/services/ffmpeg_planning/*_builder.dart` | 6 个文件 |
| 进程启动 | `lib/infrastructure/services/execution/local_ffmpeg_process_starter.dart` | ~50 行 |
| 进程观测 | `lib/infrastructure/services/execution/local_ffmpeg_process_observer.dart` | ~300 行（含 stall detection） |
| 进程控制(接口) | `lib/application/services/execution/ffmpeg_process_controller.dart` | 抽象接口 |
| 进程控制(macOS) | `lib/infrastructure/services/execution/signal_ffmpeg_process_controller.dart` | SIGSTOP/SIGCONT |
| 进程控制(Win) | `windows/.../windows_ffmpeg_process_controller.dart` | method channel |
| 输出预检 | `lib/infrastructure/services/execution/local_output_preflight_service.dart` | partial 保护 |

### 对应文件
- `docs/develop/architecture.md`「并行和资源保护」段
- `docs/develop/workflow.md`（任务执行入口规范）
- `docs/lessons.md`（stall 检测、Windows 进程控制、partial 保护等相关条目）

---

## 附录：讲解顺序建议

如果这是一次连续分享，建议按照以下顺序讲，逻辑最顺畅：

```
1. [Q1] 这个软件是干嘛的？（2min）
   ↓ 让听者知道我们在说什么

2. [Q2] 为什么还要做一个这样的软件？（3min）
   ↓ 建立动机，说明差异化价值

3. [Q4] 架构是什么样的？（5min）
   ↓ 建立整体认知骨架

4. [Q5] 为什么不用 MVVM？（3min）
   ↓ 回答常见质疑，加深架构理解

5. [Q3] 用了哪些 Skills/技术栈？（3min）
   ↓ 技术选型的why

6. [Q6] 核心部分的技术实现（8-10min）
   ↓ 高潮部分，深入硬核细节

7. Q&A（5min）
```

总计约 25-30 分钟。如果时间紧，Q3 和 Q5 可以压缩或跳过。
