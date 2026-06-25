# FrameLean 项目长期备忘

跨会话保留的稳定事实与约定。每日流水写入 `YYYY-MM-DD.md`，此处只沉淀跨会话仍有价值的内容。

## 技术栈与环境

- Flutter Desktop + FFmpeg/FFprobe + Riverpod 3 + Drift v29 + SQLite。当前 v1.2.1+5。
- Flutter SDK 3.41.2（stable），位于 `~/.flutter/sdk/3.41.2`。Dart/Flutter 命令通过 `rtk` 包装器调用（`rtk flutter analyze` / `rtk flutter test`）。
- 接近 Clean Architecture 分层，`test/architecture_dependencies_test.dart` 自动守门依赖方向。
- barrel 文件统一命名 `library.dart`（与用户跨项目偏好一致）。

## 测试与验证命令

- 全量静态分析：`rtk flutter analyze`（需关闭沙箱：会写 `~/.flutter` 引擎缓存）。
- 全量单测：`rtk flutter test`（基线 375 项通过）。
- 桌面集成烟测：`rtk flutter test integration_test/app_smoke_test.dart`（4 项，用内存 Drift 启动真实 app）。
- 架构护栏：`rtk flutter test test/architecture_dependencies_test.dart`。
- 提交前 whitespace 检查：`rtk git diff --check`。

## 关键测试边界：appRuntimeEffectsEnabledProvider

- 位置：`lib/app/providers/platform_provider.dart`，`Provider<bool>` 默认 `true`。
- 生产默认开启：系统快捷键、窗口/托盘监听、启动清理、更新自动检查。
- 集成测试 override 为 `false`，让烟测与开发机真实平台副作用隔离。
- 新增运行期副作用时，在 `app/app.dart` 与 `workbench_page.dart` 接入点用此 provider gate，避免污染集成测试。

## 跨层常量分层（2026-06-25 起）

- `lib/domain/constants.dart`：领域默认值（CRF、线程、音频比特率键）。
- `lib/application/constants.dart`：应用层共享（数据库、通道、目录、时序、超时、通知来源、预览帧、日志上限）。
- `lib/app/constants.dart`：只放 app/UI 侧常量（路由、动画、通知时长、更新平台、布局、图片质量、外链），并 `export` domain/application 常量保持一次性导入兼容。
- 低层（domain/application/infrastructure）禁止 import `app/constants.dart`，从各自层级常量文件取。

## 提交约定

- Conventional Commits + 中文描述，例：`test(app): ...`、`feat(update): ...`、`refactor(app): ...`、`fix(app): ...`。
- 工作分支：`develop/v1.2.1`。
- `.workbuddy/memory/` 日志纳入版本管理，随对应工作一起提交。
- CHANGELOG 按天合并条目，Added/Changed/Fixed/Verified 四段；可复用经验入 `docs/lessons.md`，决策入 `docs/decisions/`。

## 已知沙箱限制

- `flutter analyze` / `flutter test` 需写 `~/.flutter/sdk/.../cache/engine.stamp`，沙箱会拦截，需 `dangerouslyDisableSandbox`。
- 带 `dangerouslyDisableSandbox` 的命令可能因 shell 写 `~/.lesshsQ`（less 历史）被用户拒绝；git 读写项目内 `.git` 在沙箱内正常，无需提权。
