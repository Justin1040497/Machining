# 仓库和文档结构治理

## 所属版本

`v1.1.5`

## 当前事实

FrameLean 保留 Flutter 根工程结构，同时把本地参考、临时样本、工具状态和 worktree 收敛到 ignored 的 `.workspace/`。文档信息架构改为上下文、工作区、版本事实、决策、工程事实、参考和经验总结。

## 设计方式

- 根目录继续保留 `pubspec.yaml`、`lib/`、`test/`、`macos/`、`windows/`、`linux/` 等 Flutter 默认入口。
- 构建脚本放在 `scripts/build/`，发布脚本放在 `scripts/release/`。
- 分发法律材料放在 `legal/`，运行时和可追溯三方产物放在 `third_party/`。
- `.workspace/` 用于本地参考、样本、临时材料和 worktree，不进入版本库。
- 文档不再使用常规 `archive/`、`features/`、`plans/` 和 `product/roadmap.md` 入口。

## 为什么这样设计

当前项目是单个 Flutter 桌面应用，迁移到 monorepo 会增加平台工程、脚本、CI 和发布风险。文档方面，旧结构中的过程文档和碎片日志太多，容易让人和 AI 把过期计划当成当前事实。

## 设计收益

- Flutter 工具链保持默认路径。
- 根目录和文档目录更容易阅读。
- 版本事实、决策、经验和当前任务各自有稳定入口。

## 关联

- `docs/decisions/260606-repository-structure.md`
- `docs/decisions/260608-docs-information-architecture.md`
- `docs/README.md`
