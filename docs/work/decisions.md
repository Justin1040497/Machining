# 有效决策索引

这里列出当前仍有效的重要决策。正文放在 `docs/decisions/`，版本事实说明放在 `docs/releases/`。

| 日期 | 决策 | 状态 | 正文 | 关联事实 |
| --- | --- | --- | --- | --- |
| 260612 | macOS 使用单一 Universal 2 DMG 支持 x86_64 / arm64，Windows 继续只支持 x64 | 有效 | `docs/decisions/260612-macos-universal2-distribution.md` | `docs/releases/v1.2.0/macos-universal2.md` |
| 260608 | 项目级 skills 从阶段拆分改为职责拆分，临时计划进入 `.workspace/` | 有效 | `docs/decisions/260608-project-skill-workflow.md` | `docs/releases/v1.1.5/project-skills-workflow.md` |
| 260608 | 文档信息架构改为上下文、工作区、版本事实、决策和经验总结 | 有效 | `docs/decisions/260608-docs-information-architecture.md` | `docs/releases/v1.1.5/repository-structure.md` |
| 260607 | 任务拖拽排序先乐观更新 UI，再后台持久化排序 | 有效 | `docs/decisions/260607-task-reorder-optimistic-update.md` | `docs/releases/v1.1.5/workbench-theme-and-reorder.md` |
| 260607 | Drift 新增列迁移统一使用幂等 `_safeAddColumn` | 有效 | `docs/decisions/260607-drift-migration-safe-add-column.md` | `docs/develop/data-model.md` |
| 260606 | 仓库结构保留 Flutter 根工程，不迁移到 monorepo | 有效 | `docs/decisions/260606-repository-structure.md` | `docs/releases/v1.1.5/repository-structure.md` |
