# 仓库结构保留 Flutter 根工程

## 状态

有效

## 决策

FrameLean 保留 Flutter 根工程结构，不迁移到 `apps/desktop/` monorepo。仓库根目录继续保留 `pubspec.yaml`、`lib/`、`test/`、`macos/`、`windows/`、`linux/` 等 Flutter 默认入口。

本地参考、样本、临时材料和 worktree 统一放入 `.workspace/`，并保持 ignored。

## 原因

当前项目是单个 Flutter 桌面应用。迁移到 monorepo 会牵动平台工程、脚本、CI、路径解析、发布流程和 Flutter 插件注册，成本明显高于收益。

## 收益

- 保持 Flutter 工具链默认路径，减少构建风险。
- 根目录边界更清晰：源码、平台工程、文档、三方运行时、法律材料、本地工作区各有位置。
- 后续若真的出现后端、共享包或多应用结构，再单独评估 monorepo。

## 关联

- `docs/releases/v1.1.5/repository-structure.md`
