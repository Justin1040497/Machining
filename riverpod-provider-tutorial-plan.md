# Riverpod 与 Provider 教学 Demo 方案

> 目标：用**单一贯穿场景**递进式演示，让听者理解「为什么不直接用 StatefulWidget/StatelessWidget」，以及 `provider` 与 `riverpod` 两个库的**使用差异、效果差异、各自不足**。
>
> 听者画像：会写 Widget、懂 `build/setState`，但没用过状态管理库。
>
> 叙事线：**项目驱动 + 两库对比**。以一个真实小应用为载体，先用 ful/less 裸写暴露痛点，再用 provider 改写看它解决了什么/留下什么，最后用 riverpod 改写看它如何解决 provider 的不足，并客观指出 riverpod 自己的坑。

---

## 0. 前置认知（录制开篇必须讲清的 3 件事）

1. **两个库的关系**：`provider` 与 `riverpod` 是同一作者 Remi Rousselet 的两代作品。`riverpod` 名字是 **Ri**verso（反转）+ **Provider** 的重组，定位是「provider 的精神继承者」。所以对比不是「两个并列竞品」，而是「上一代 vs 下一代」。

2. **版本基线**（与本项目一致）：
   - `flutter_riverpod: ^3.3.1`（Riverpod 3.x，**手写 provider，不用 codegen**，和 FrameLean 项目一致）
   - `provider: ^6.x`（最新稳定版）
   - ⚠️ Riverpod 3.x 现状纠偏：`NotifierProvider` / `AsyncNotifierProvider` 是主力；`StateProvider` 已不推荐、`StateNotifierProvider` 边缘化。Demo 以 3.x 主流 API 为准，避免教过时写法。

3. **三档素材优先级**（每道题都标注出处）：
   - ① 官方示例（riverpod.dev / pub.dev provider 文档）
   - ② 成熟项目典型用法
   - ③ 本项目 FrameLean 实际使用（`lib/app/providers/*`、`lib/features/workbench/providers/*`）

---

## 1. 贯穿场景：LeanTask 迷你工作台

一个本地任务清单小应用，功能足以覆盖两个库的全部用法：

| 模块 | 功能 | 对应状态管理需求 |
|---|---|---|
| 任务列表 | 增删改、排序、标记完成 | 可变状态（Notifier/ChangeNotifier） |
| 任务分组 | 任务可归入「文件夹」 | 派生状态、失效重算 |
| 异步加载 | 启动从本地存储读初始数据 | FutureProvider / Async 三态 |
| 实时进度 | 「进行中」任务进度每秒 +0.1，满 1.0 转完成 | StreamProvider + 副作用 |
| 全局设置 | 主题模式（亮/暗）、是否自动开始 | 跨页面共享、依赖注入 |
| 派生统计 | 待办/进行中/已完成数量、完成率 | select / 精准重建 |
| 依赖注入 | 存储服务 TaskRepository、时钟服务 ProgressClock | Provider 注入 + override 测试 |

> 选这个场景的理由：与你的 FrameLean（媒体压缩工作台：任务列表 + 文件夹 + 设置 + 队列进度）**同构**，第三档素材可直接对应，听者学完能迁移到真实项目。

---

## 2. 三幕题目（共 16 题）

### 第〇幕 引子：ful/less 的天花板（回答「为什么不直接用」）

#### 题目 0
```
# 题目0：用纯 StatefulWidget 实现 LeanTask
# 维护一个任务列表，支持新增、删除、标记完成
# 顶部显示「待办 / 进行中 / 已完成」数量统计
# 另有一个设置页可切换主题模式（亮 / 暗）
# 要求：任务列表页和设置页都能读到当前主题并实时响应切换
# 限制：只能用 StatefulWidget / StatelessWidget / InheritedWidget，不得引入任何状态管理库
```

- **考查点**：`setState` 的边界、状态提升、手写 `InheritedWidget` 的样板、跨页共享、重建范围失控、难以单元测试。
- **素材出处**：① Flutter 官方 InheritedWidget / setState 文档；② 早期 Flutter 项目「巨树 + InheritedWidget」模式；③ 本项目无对应（从一开始就用 riverpod，可反问「如果本项目用 ful/less 会怎样」）。
- **对比要点**：暴露 5 个痛点——状态提升导致上层 Widget 臃肿、跨页传递需层层透传、`setState` 重建范围无法精确控制、`InheritedWidget` 样板代码多、状态逻辑无法脱离 Widget 测试。**这 5 个痛点正是两个库要解决的目标。**

---

### 第一幕 Provider 库

#### 题目 1
```
# 题目1：用 ChangeNotifierProvider 接管任务列表状态
# 新建 TaskListModel extends ChangeNotifier，持有 List<Task>
# 新增 / 删除 / 标记完成时调用 notifyListeners()
# 顶部统计区用 Consumer 包裹，列表用 context.watch 读取
# 要求：移除上层 StatefulWidget 的 setState，统计区与列表各自独立刷新
```

- **API**：`ChangeNotifierProvider`、`ChangeNotifier.notifyListeners()`、`Consumer`、`context.watch`。
- **素材出处**：① provider 官方 README 的 ChangeNotifierProvider 示例；② Flutter 官方早期计数器/购物车示例；③ 本项目无 provider 包，对应 riverpod 的 `NotifierProvider`。
- **对比要点**：解决了「状态提升」，但 `ChangeNotifier` 是**可变**状态、`notifyListeners` 粒度粗（整树重建）、仍依赖 `BuildContext`。

#### 题目 2
```
# 题目2：引入存储服务与时钟服务，做依赖注入
# 用 Provider 注入 TaskRepository（异步加载）和 ProgressClock
# 用 MultiProvider 在 main.dart 顶层组合多个 Provider
# 列表页通过 context.read<TaskRepository>() 调用，不触发重建
# 要求：区分 Provider（只读值）与 ChangeNotifierProvider（可变状态）
```

- **API**：`Provider`、`MultiProvider`、`context.read`、`Provider.value`。
- **素材出处**：① provider 文档「Reading values」；② 典型 main.dart 顶层 `MultiProvider`；③ 本项目对应 `appDatabaseProvider = Provider<AppDatabase>((ref) {...})`、`ffmpegProcessStarterProvider`。
- **对比要点**：provider 的 `Provider` vs riverpod 的 `Provider`——后者不依赖 `BuildContext`，可在任意层读取。

#### 题目 3
```
# 题目3：应用启动时异步从本地加载初始任务
# 用 FutureProvider<List<Task>> 包裹 repository.loadAll()
# 列表页根据 AsyncSnapshot 的 connectionState 分 loading / error / data 三态渲染
# 加载失败时显示重试按钮
```

- **API**：`FutureProvider`、`AsyncSnapshot`、`ConnectionState`。
- **素材出处**：① provider 文档 FutureProvider；② 启动加载配置的常见写法；③ 本项目 `appSettingsProvider = FutureProvider<AppSettings>((ref) {...})`。
- **对比要点**：provider 返回 `AsyncSnapshot`（较原始）；riverpod 返回 `AsyncValue`（更统一、可缓存、可 `invalidate` 重试）。

#### 题目 4
```
# 题目4：任务「进行中」时进度每秒 +0.1，满 1.0 自动转「已完成」
# 用 StreamProvider<double> 暴露当前选中任务的进度流
# 进度条用 context.watch 监听；满 1.0 时列表数量统计自动更新
```

- **API**：`StreamProvider`、`Stream`。
- **素材出处**：① provider 文档 StreamProvider；② 实时数据流；③ 本项目用 `Timer.periodic` 轮询模拟（`MediaTaskListNotifier.startExecutionRefreshPolling`），可对比流式更优。
- **对比要点**：两库 `StreamProvider` 形态接近；riverpod 可 `invalidate` 重新订阅，provider 难。

#### 题目 5
```
# 题目5：统计区只依赖「各状态数量」，不依赖任务标题等细节
# 用 Selector<TaskListModel, ({int todo, int running, int done})> 只在数量变化时重建
# 验证：修改任务标题时，统计区不重建（用 print 证明 build 未触发）
```

- **API**：`Selector`、`shouldRebuild` 判等。
- **素材出处**：① provider 文档 Selector；② 性能优化典型；③ 本项目对应 riverpod 的 `ref.watch(provider.select(...))`。
- **对比要点**：provider 的 `Selector` 需手写判等函数；riverpod 的 `select` 更轻量、且可与 `ref.listen` 组合做副作用。

#### 题目 6
```
# 题目6：任务列表依赖 TaskRepository，repository 又依赖 Settings（autoStart 影响加载策略）
# 用 ChangeNotifierProxyProvider<Settings, TaskListModel> 让列表在 settings 变化时重建
# 要求：切换 autoStart 后，列表重新加载
```

- **API**：`ProxyProvider` / `ChangeNotifierProxyProvider`。
- **素材出处**：① provider 文档 ProxyProvider；② 依赖链注入；③ 本项目对应 riverpod 里直接 `ref.watch(settingsProvider)` 串联，**无 Proxy 概念**。
- **对比要点**：**这是 provider 最大的痛点之一**——`ProxyProvider` 笨重、`previous` 参数易错、重建整个 ChangeNotifier。riverpod 用 `ref.watch` 一行解决。
- **小结 provider 的不足**（题6 收尾讲）：① 强依赖 `BuildContext`，无法跨树/非 Widget 层访问；② `ProxyProvider` 复杂易错；③ `dispose` 易泄漏；④ 测试需堆叠 `MultiProvider` + `WidgetTester`；⑤ `ChangeNotifier` 可变状态难追踪。

---

### 第二幕 Riverpod 库

#### 题目 7
```
# 题目7：用 Riverpod 重构依赖注入
# main.dart 包裹 ProviderScope，用 Provider 注入 TaskRepository 和 ProgressClock
# 用 override 在测试中替换为 Mock
# 要求：services 不再依赖 BuildContext，可在非 Widget 层直接读取
```

- **API**：`ProviderScope`、`Provider`、`overrides`、`overrideWith`。
- **素材出处**：① riverpod 官方「Creating your first provider」；② 主流 riverpod 项目 main 结构；③ 本项目 `main.dart` 的 `ProviderScope(overrides: [appDatabaseProvider.overrideWith(...), initialAppSettingsProvider.overrideWithValue(...)])`。
- **对比要点**：摆脱 `BuildContext` 是 riverpod 杀手锏之一——状态逻辑可在纯 Dart 层测试与复用。

#### 题目 8
```
# 题目8：用 NotifierProvider 替代 ChangeNotifier
# 定义 TaskListNotifier extends Notifier<List<Task>>，用 state = [...] 更新
# 列表页用 ConsumerWidget + ref.watch 读取
# 新增 / 删除用 ref.read(taskListProvider.notifier).add(...)
# 要求：state 不可变，每次返回新 List
```

- **API**：`NotifierProvider`、`Notifier`、`state`、`ConsumerWidget`、`ref.watch`、`ref.read`、`.notifier`。
- **素材出处**：① riverpod 官方 NotifierProvider；② riverpod 2/3 主流状态写法；③ 本项目 `MediaTaskListNotifier extends AsyncNotifier<List<MediaTask>>`（同步版 `Notifier` 的异步兄弟）。
- **对比要点**：不可变 `state` vs `ChangeNotifier` 可变内部字段；`notifier` 模式让「读取状态」与「触发动作」清晰分离。

#### 题目 9
```
# 题目9：把任务列表改为异步加载，初始从本地读取
# TaskListNotifier extends AsyncNotifier<List<Task>>，build() 返回 Future
# 列表页用 ref.watch(taskListProvider) 拿到 AsyncValue<List<Task>>
# 用 .when(data: / loading: / error:) 分态渲染，错误态提供重试（ref.invalidate）
```

- **API**：`AsyncNotifierProvider`、`AsyncNotifier`、`AsyncValue`、`.when`、`ref.invalidate`。
- **素材出处**：① riverpod 官方 AsyncNotifierProvider / AsyncValue；② 异步列表标准范式；③ 本项目 `mediaTaskListProvider = AsyncNotifierProvider<MediaTaskListNotifier, List<MediaTask>>(...)`，`build()` 里 `ref.watch` 多个依赖、`ref.onDispose` 释放 Timer。
- **对比要点**：`AsyncValue` 比 `AsyncSnapshot` 更统一（data/loading/error 三态合一、可缓存、可 `invalidate` 重试、可 `.valueOrNull`）。

#### 题目 10
```
# 题目10：用 FutureProvider 加载设置，用 StreamProvider 暴露进度流
# 设置页用 ref.watch(settingsProvider) 分态显示
# 进度条用 ref.watch(progressProvider) 监听流
# 进度满 1.0 时用 ref.listen 自动把任务标记完成（副作用与 UI 分离）
```

- **API**：`FutureProvider`、`StreamProvider`、`ref.listen`（副作用）。
- **素材出处**：① riverpod 官方 FutureProvider / StreamProvider / ref.listen；② 配置 + 实时流；③ 本项目 `appSettingsProvider`(FutureProvider)、`executionProvider` 轮询可改 StreamProvider；`ref.listen` 对应本项目 `state = AsyncData(...)` 后的 `syncFfmpegQueueStatus()` 副作用。
- **对比要点**：`ref.listen` 是 provider 没有的——副作用（写日志、弹通知、联动其他 provider）与 UI 渲染分离，UI 只管显示。

#### 题目 11
```
# 题目11：统计区只依赖各状态数量
# 方式A：定义派生 Provider：final statsProvider = Provider((ref) { final list = ref.watch(taskListProvider).valueOrNull ?? []; return 统计; })
# 方式B：用 ref.watch(taskListProvider.select((v) => 只取数量))
# 验证：改标题时统计区不重建
```

- **API**：派生 `Provider`、`select`、`valueOrNull`。
- **素材出处**：① riverpod 官方「Combining provider states」/ select；② 派生状态典型；③ 本项目多处 `ref.watch` 串联，如 `previewFrameGeneratorProvider` 依赖 `defaultFfmpegCommandBuilderProvider` 与 `compressionAdvisorProvider`。
- **对比要点**：派生状态在 riverpod 里就是普通 `ref.watch` 串联，比 `ProxyProvider` 优雅太多——这是题6 痛点的直接解药。

#### 题目 12
```
# 题目12：支持「多任务详情页」，每个任务一个独立进度状态
# 用 family 定义 taskProgressProvider(taskId) → StreamProvider
# 离开详情页时用 autoDispose 自动停止流、释放资源
# 验证：打开后关闭详情页，流被取消（print onCancel）
```

- **API**：`family`、`autoDispose`、`ref.onDispose`。
- **素材出处**：① riverpod 官方 family / autoDispose（**3.x 注意 autoDispose 语义变化**）；② 按 id 参数化；③ 本项目 `ref.onDispose(() => executionRefreshTimer?.cancel())`。
- **对比要点**：provider 的 `family` 几乎无等价物；`autoDispose` 解决 provider 的 dispose 泄漏痛点。
- **⚠️ 版本提醒**：Riverpod 3.x 中 `autoDispose` 不再需要显式修饰符（默认行为有调整），录制时务必以 3.3.1 实际表现为准，别用 2.x 旧语法。

#### 题目 13
```
# 题目13：为任务列表写单元测试
# 用 ProviderScope(overrides: [taskRepositoryProvider.overrideWithValue(MockRepo())])
# 用 ProviderContainer 测试 notifier：container.read(taskListProvider.notifier).add(...)
# 断言 state 变化，无需 WidgetTester
```

- **API**：`overrideWithValue`、`ProviderContainer`、`container.read/listen`。
- **素材出处**：① riverpod 官方 Testing；② riverpod 项目测试范式；③ 本项目 `main.dart` 的 `overrides`（初始化覆盖，与测试同机制）。
- **对比要点**：**riverpod 可脱离 Widget 测纯逻辑**；provider 测试要 `MultiProvider` + `WidgetTester`。这是 riverpod 对 provider 的碾压级优势。

---

### 第三幕 对比与选型

#### 题目 14
```
# 题目14：输出一份对比报告
# 同一「任务列表 + 设置 + 统计」需求，列出 provider 与 riverpod 在以下维度的差异：
#   状态可变性 / 依赖注入方式 / 是否依赖 BuildContext / 重建粒度
#   异步三态 / 副作用机制 / 参数化(family) / 自动释放 / 可测试性
# 分别列出两个库各自的「不足 / 坑」
# 给出选型建议：何时仍可用 provider，何时该用 riverpod
```

- **素材出处**：① riverpod 官方「Why riverpod」/「Migration from provider」；② 社区选型共识。
- **provider 的不足**：BuildContext 耦合、ProxyProvider 笨重、dispose 易泄漏、测试需 Widget 树、ChangeNotifier 可变难追踪。
- **riverpod 的不足（客观讲）**：① 学习曲线陡（概念多：ref/AsyncValue/family/autoDispose）；② 3.x API 变动大（StateProvider 弃用、autoDispose 语义变），老资料易误导；③ codegen 可选增加心智负担；④ 老项目迁移成本高；⑤ 包体积与编译时间略增。
- **选型建议**：新项目首选 riverpod；维护中的老 provider 项目可逐步迁移；纯简单静态页 ful/less 仍够用。

#### 题目 15（收尾）
```
# 题目15：拆解真实项目 FrameLean
# 打开 lib/app/providers 与 lib/features/workbench/providers
# 指出 appDatabaseProvider / appSettingsProvider / mediaTaskListProvider 分别用了哪种 Provider
# 解释 build() 里的 ref.watch 依赖链、ref.invalidate 的失效重算、ref.onDispose 的资源释放
# 对照前面的题，说明「真实项目里 riverpod 是怎么用的」
```

- **素材出处**：③ 本项目本身——`database_provider.dart`、`app_settings_provider.dart`、`media_task_notifier.dart`、`execution_provider.dart`、`main.dart`。
- **价值**：从 Demo 到真实项目落地，让听者看到「生产级代码长这样」。

---

## 3. 知识点覆盖核对矩阵

| 知识点 | provider | riverpod | 覆盖题号 |
|---|---|---|---|
| 值/依赖注入 | `Provider` + `MultiProvider` | `Provider` + `ProviderScope` | 2 / 7 |
| 可变状态 | `ChangeNotifierProvider` | `NotifierProvider` | 1 / 8 |
| 异步加载 | `FutureProvider`(AsyncSnapshot) | `FutureProvider` + `AsyncValue` | 3 / 9 / 10 |
| 异步有状态 | （无原生等价，靠 ChangeNotifier 混合） | `AsyncNotifierProvider` | 9 |
| 流 | `StreamProvider` | `StreamProvider` | 4 / 10 |
| 精准重建 | `Selector` | `select` | 5 / 11 |
| 跨依赖 | `ProxyProvider` | `ref.watch` 串联 | 6 / 11 |
| 副作用 | （无，靠 setState/回调） | `ref.listen` | 10 |
| 参数化 | （无） | `family` | 12 |
| 自动释放 | 手动 `dispose` | `autoDispose` + `ref.onDispose` | 12 |
| 失效重算 | （无） | `ref.invalidate` / `ref.refresh` | 9 / 11 |
| 测试 | `MultiProvider` + WidgetTester | `ProviderContainer` 纯逻辑 | 13 |
| 读取 | `context.watch/read`、`Consumer` | `ref.watch/read`、`ConsumerWidget` | 1-6 / 7-13 |
| 初始化覆盖 | `MultiProvider` 顶层替换 | `ProviderScope.overrides` | 7 / 13 |

> ✅ 两个库的全部主流用法均有对应题目。

---

## 4. 录制建议

### 4.1 时长配比（按总时长 100% 估算）
- 第〇幕（题0）：约 15%——痛点要讲透，是后续所有动机的根。
- 第一幕（题1-6）：约 30%——provider 重点在题6 的 ProxyProvider 痛点。
- 第二幕（题7-13）：约 40%——riverpod 主力，题9/题11/题13 是高潮。
- 第三幕（题14-15）：约 15%——对比收尾 + 真实项目落地。

### 4.2 Demo 项目结构建议
```
lean_task/
├── lib/
│   ├── main.dart                  # 题7: ProviderScope + overrides
│   ├── app.dart                   # MaterialApp + 路由
│   ├── domain/                    # Task / Folder / Settings 模型
│   ├── data/                      # TaskRepository / ProgressClock
│   ├── providers/                 # 题7-13: 所有 riverpod provider
│   │   ├── task_list_provider.dart
│   │   ├── settings_provider.dart
│   │   ├── progress_provider.dart
│   │   └── stats_provider.dart
│   ├── features/
│   │   ├── task_list/             # 列表页（题1/8/9）
│   │   ├── settings/              # 设置页（题3/10）
│   │   ├── stats/                 # 统计区（题5/11）
│   │   └── task_detail/           # 详情页（题12 family）
│   └── widgets/
├── test/                          # 题13: ProviderContainer 单测
└── pubspec.yaml                   # flutter_riverpod: ^3.3.1
```

### 4.3 每题讲解节奏（推荐 4 段式）
1. **念题目**（30s）——用上面的编程题描述。
2. **演示实现**（核心）——现场敲或切到预备代码，重点讲 API 形态。
3. **对比**（关键）——和上一题/另一库的实现并排，强调「差异」与「效果差异」。
4. **点不足**（收尾）——这题暴露了什么问题，引出下一题。

### 4.4 关键提醒
- riverpod 3.x 语法为准，**不要**用 2.x 旧资料里的 `StateNotifierProvider` / `StateProvider` 当主力。
- 本项目未用 codegen，Demo 也保持手写 `final xxxProvider = ...`，与项目一致，降低听者迁移成本。
- 题12 的 `autoDispose` 务必以 3.3.1 实际表现为准，录制前先跑一遍验证。

---

## 5. 后续动作（待你决定）

- [ ] 确认场景：用 LeanTask（推荐，与本项目同构），还是换购物车/番茄钟？
- [ ] 确认题目粒度：16 题是否合适？需要拆分/合并/增删？
- [ ] 是否需要我**从零创建这个 Flutter Demo 项目并写出每题的完整代码**？（当前只交付了方案，尚未写代码）
- [ ] 是否需要为每题准备**可复制的代码片段 + 讲解脚本**？
