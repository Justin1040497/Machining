# library.dart barrel 导出与导入边界治理

## 状态

已实施（2026-06-23）。

## 背景

FrameLean 的目录已按 `domain`、`application`、`infrastructure`、`features`、`app` 分层，导入风格也已完成 package 化（全项目 `package:framelean/...` 导入，相对路径为 0）。但导入管理存在三个缺口：

1. **无 barrel 导出契约**。跨层调用直达具体文件，例如 `infrastructure/database/app_database.dart` 直接 `import 'package:framelean/app/constants.dart'`，调用方与被调方的内部实现耦合，被调方重构文件路径会波及所有调用方。
2. **无强制保护**。`analysis_options.yaml` 仅启用默认 `flutter_lints`，未启用 `always_use_package_imports`。相对路径为零是靠惯性维持，新人或新文件随时可能回退。
3. **导出零散**。全项目仅 3 个文件带局部 `export`，无聚合门面，层的公共 API 边界不清晰。

现有 ADR `260614-clean-architecture-composition-root.md` 已定义依赖方向并有 `test/architecture_dependencies_test.dart` 自动检查，本决策聚焦导入与导出管理，不重复依赖方向治理。

## 决策

采用「单 package + barrel 白名单封装」方案，统一 barrel 命名为 `library.dart`，一次性全量迁移。

### 1. barrel 布局：7 个 `library.dart` 入口

| barrel 路径 | 覆盖范围 | 角色 |
|---|---|---|
| `lib/domain/library.dart` | entities / enums / services / value_objects | 领域模型公共 API |
| `lib/application/library.dart` | repositories / services / use_cases | 应用层用例与端口 |
| `lib/infrastructure/library.dart` | database / repositories / services | 基础设施实现 |
| `lib/app/library.dart` | presentation / providers / theme / shortcuts / notifications + 根文件 | 编排与共享展示 |
| `lib/features/notifications/library.dart` | 通知中心功能模块 | 功能边界入口 |
| `lib/features/settings/library.dart` | 设置功能模块 | 功能边界入口 |
| `lib/features/workbench/library.dart` | 工作台功能模块 | 功能边界入口 |

命名约定：**所有 barrel 统一叫 `library.dart`**。看到 `library.dart` 即知是层/模块的导出门面。此约定顺带解决了 `lib/app/app.dart`（根 Widget）与 barrel 的命名冲突——barrel 叫 `library.dart`，根 Widget 保持 `app.dart` 不动。

### 2. 导出策略：白名单封装

每个 `library.dart` 只显式 `export` 该层/模块的**公共 API**，内部实现文件不导出。

示例（`lib/domain/library.dart`）：
```dart
export 'entities/media_task.dart';
export 'entities/task_folder.dart';
export 'entities/app_settings.dart';
export 'entities/app_notification_entry.dart';
export 'value_objects/media_task_config.dart';
export 'value_objects/video_processing_config.dart';
export 'value_objects/audio_processing_config.dart';
export 'value_objects/image_processing_config.dart';
export 'value_objects/app_compression_settings.dart';
export 'value_objects/app_shortcut_binding.dart';
export 'value_objects/app_update_state.dart';
export 'value_objects/app_release_info.dart';
export 'value_objects/media_analysis_result.dart';
export 'value_objects/update_notification_payload.dart';
export 'value_objects/video_output_compatibility.dart';
export 'enums/media_output_format.dart';
// domain/services/ 下的内部辅助类不导出
```

导出原则：
- **跨层需要的类型才导出**。仅同层内部使用的辅助类、mixin、工具函数不进 barrel。
- **新增公共类型时手动加一行 `export`**。这是白名单的代价，换取封装清晰与重构安全。
- barrel 文件**只写 export，不写逻辑**。

### 3. 导入规则

| 场景 | 规则 | 示例 |
|---|---|---|
| 跨层导入 | **必须经 barrel** | `import 'package:framelean/domain/library.dart';` |
| 同层内部导入 | 直达文件，不经 barrel | `import 'package:framelean/domain/entities/media_task.dart';` |
| 第三方依赖 | 不受影响 | `import 'package:drift/drift.dart';` |
| 相对路径 | **完全禁止** | `import '../domain/...'` → lint 报错 |

同层内部允许直达文件，因为这些是内部实现细节，不在 barrel 白名单内。跨层必须经 barrel，以建立封装边界。

### 4. lint 强制

在 `analysis_options.yaml` 启用：
```yaml
linter:
  rules:
    always_use_package_imports: true
```

此规则禁止所有相对路径导入（`../`、`./`），强制使用 `package:` 导入。对 `part` / `part of` 指令无影响（它们不是 import）。

跨层必须经 barrel 的约束，Dart lint 无原生支持。先靠 code review + 本次迁移建立惯例；如需自动检查，可后续引入 `import_lint` 第三方包自定义规则（作为可选增强，不在本次范围）。

### 5. 一次性全量迁移步骤

现状已无相对路径，迁移工作聚焦于「直达文件的跨层导入 → 经 barrel 导入」。

1. **创建 7 个 `library.dart`**，按白名单原则填写导出清单。逐层梳理公共类型，内部实现不导出。
2. **改写跨层导入**。扫描所有 `import 'package:framelean/<他层>/...'`，改为 `import 'package:framelean/<他层>/library.dart'`。同层直达导入保留。
3. **启用 lint**。在 `analysis_options.yaml` 加 `always_use_package_imports: true`。
4. **全量验证**：
   - `flutter analyze`（零 warning）
   - `flutter test`（含 `test/architecture_dependencies_test.dart` 依赖方向检查）
   - `flutter pub run build_runner build`（drift codegen 不受影响，因 part 指令非 import）
5. **重点核查重灾区**：`features/workbench/pages/workbench_page.dart`（51 处导入）、`features/settings/pages/app_settings_page.dart`（50 处）、`features/workbench/providers/media_task_notifier.dart`（26 处）、`app/providers/app_update_provider.dart`（27 处）、`app/providers/input_runtime_provider.dart`（22 处）。

### 6. 特殊文件处理

| 类型 | 处理方式 |
|---|---|
| drift 生成产物（`*.g.dart`） | `part` 指令关联，非 import，不受 lint 影响。源文件的 import 按规则迁移即可。 |
| `part` / `part of`（仅 2 处） | 不受 `always_use_package_imports` 约束，保持现状。 |
| `test/` 目录 | 纳入同一规则，禁用相对路径，经 barrel 导入被测模块。 |
| `lib/main.dart` | 作为启动入口，可达文件导入 `app/library.dart`。 |

## 结果

- **导入更稳定**：跨层调用经 barrel，被调方内部重构文件路径不影响调用方。
- **封装边界清晰**：每层 `library.dart` 的 export 清单即公共 API 契约，内部实现可自由演进。
- **相对路径永久禁用**：lint 强制，防止回退。
- **未来可演进**：若日后需拆 monorepo，7 个 `library.dart` 即天然的包边界，迁移成本低。

## 代价

- **白名单维护成本**：新增公共类型需手动加 `export`。权衡：换取封装清晰与重构安全。
- **跨层 barrel 约束非自动**：依赖 code review 维持，`import_lint` 为可选增强。
- **一次性迁移风险**：重灾区文件导入数高，改动集中。缓解：迁移后立即 `flutter analyze` + 全量测试。

## 实施结果（2026-06-23）

- 创建 7 个 `library.dart` barrel，按白名单封装原则填写导出清单。
- 批量改写 165 个文件，移除 789 处跨层直达导入，替换为经 barrel 导入。
- `analysis_options.yaml` 启用 `always_use_package_imports: true`。
- 修复 `lib/main.dart` 和 `lib/app/app.dart` 的残留相对路径。
- 修复 `lib/app/presentation/widgets/reorderable/framelean_reorderable_list_view.dart` 的相对路径导入。
- `flutter analyze lib/` 零 warning。
- `flutter test` 通过 357 个；失败 12 个全部集中在 `test/app_update_provider_test.dart` 同一测试（timeout + provider dispose），经 baseline 对比确认是预存稳定性问题，与本次改写无关。
- 架构依赖测试 `test/architecture_dependencies_test.dart` 失败 4 处，经 baseline 对比（baseline 失败 9 处）确认是预存依赖方向违规（domain/infrastructure → app），barrel 聚合后反而让违规更集中可见。这些违规属于 ADR `260614` 的治理范围，不在本次边界内。

## 边界

- 本决策不改变现有依赖方向（由 ADR `260614` 治理，`test/architecture_dependencies_test.dart` 检查）。
- 不引入 melos / monorepo，保持单 `framelean` package。
- 不改变 drift schema、媒体处理规则和用户可见行为。
- `library.dart` 仅作导出门面，不承载逻辑。

## 关联

- `docs/decisions/260614-clean-architecture-composition-root.md`（依赖方向与装配）
- `docs/develop/architecture.md`（分层架构）
- `docs/develop/workflow.md`（开发流程）
