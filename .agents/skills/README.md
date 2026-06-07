# FrameLean Skills 使用说明

本目录保存 FrameLean 项目级 skills。它们只服务当前仓库，不默认创建到用户级目录。

## 项目级 Skill 规则

- 项目级 skill 必须放在 `.agents/skills/`。
- 项目级 skill 名称必须使用 `framelean-` 前缀。
- 不创建 skill 级 `README.md`、`CHANGELOG.md`、安装说明或过程记录。
- 新增、删除、合并或重命名 skill 后，同步更新本文件和 `framelean-workflow/SKILL.md`。
- 临时分析、设计、任务和 release 草稿放入 `.workspace/`，不写入 `docs/`。
- `docs/` 只保存当前仍有效的项目事实、版本事实、决策、经验和工作池。

## 共享预读协议

所有 FrameLean skills 开工前先了解当前项目，但按需递增读取，避免浪费上下文。

### Level 1：项目事实

默认先读：

```text
AGENTS.md
CONTEXT.md
CHANGELOG.md
docs/README.md
docs/work/active.md
docs/work/backlog.md
docs/work/decisions.md
```

### Level 2：领域事实

按本次任务选择性读取：

```text
docs/releases/{相关版本}/*
docs/decisions/{相关决策}.md
docs/lessons.md
docs/develop/architecture.md
docs/develop/data-model.md
docs/develop/technology-stack.md
docs/develop/test-plan.md
docs/develop/workflow.md
docs/reference/*
```

### Level 3：代码事实

只有当任务需要分析、实现或验证具体功能时才读取源码：

- 先用 `rg` 搜模块名、类名、文件名、功能关键词。
- 只打开命中的相关源码、测试、脚本和配置。
- 不为了“了解项目”全量读取 `lib/`、`test/`、`scripts/`。

### Level 4：Git 事实

只有 `framelean-validation`、`framelean-delivery`、`framelean-release` 或用户明确要求 Git 状态时读取：

```text
git status --short
git branch --show-current
git diff --stat
git diff
git log
git tag
```

## `.workspace` 约定

```text
.workspace/
  plans/
    YYMMDD-feature-slug.md
  release-drafts/
    vX.Y.Z.md
```

- `framelean-feature-plan` 使用 `.workspace/plans/` 保存已确认需要落盘的设计、计划和任务。
- `framelean-release` 可以使用 `.workspace/release-drafts/` 保存讨论中的 release 草稿。
- `.workspace/` 不进入版本库；稳定事实由 `framelean-delivery` 或确认后的 `framelean-release` 写入 `docs/`。

## Skill 路由表

| 用户意图 | 使用 skill | 主要产物 |
| --- | --- | --- |
| 不确定该用哪个 FrameLean skill、要求完整流程或横跨多个阶段 | `framelean-workflow` | 路由和执行顺序 |
| 讨论候选需求，确认后加入需求池 | `framelean-requirement-pool` | `docs/work/backlog.md` |
| 分析功能、整理需求、梳理现有模块、写交互链或逻辑树 | `framelean-feature-analysis` | 默认内联；必要时引用需求池 |
| 写设计、比较方案、拆任务、列验证边界 | `framelean-feature-plan` | `.workspace/plans/YYMMDD-feature-slug.md` 或内联计划 |
| 实现已确认的代码、测试、脚本、文档或项目级 skill 改动 | `framelean-implementation` | 源码、测试、脚本、文档或 skill 变更 |
| 写验证计划、审查 diff、运行检查、解释失败、复验 | `framelean-validation` | 验证计划、审查发现、命令结果 |
| 校准项目事实文档，准备 commit 信息和 PR description | `framelean-delivery` | 文档校准、Markdown commit 信息、Markdown PR 描述 |
| 根据用户指定版本号总结并产出 release 文档 | `framelean-release` | `docs/releases/vX.Y.Z/release.md` |
| 创建、合并、删除或重构 FrameLean 项目级 skills | `framelean-skill-create` | `.agents/skills/framelean-*` 和路由更新 |

## 推荐流程

常规功能：

```text
framelean-requirement-pool
framelean-feature-analysis
framelean-feature-plan
framelean-implementation
framelean-validation
framelean-delivery
```

发布文档：

```text
framelean-release
```

项目级 skill 维护：

```text
framelean-skill-create
framelean-implementation
framelean-validation
framelean-delivery
```

## 共同底线

- 先读共享预读协议要求的项目事实，再按需读领域事实、代码事实和 Git 事实。
- 如果用户没有指定新需求，`framelean-feature-analysis` 应先从 `docs/work/backlog.md` 推荐未完成需求。
- 不在 `main` 上直接做日常开发改动。
- 不 stage、commit、push、revert、delete 或格式化无关用户改动。
- 不创建 `docs/archive/`、`docs/features/`、`docs/plans/` 或 `docs/product/roadmap.md`。
- 不把 `.workspace/` 的临时计划当作长期事实；长期事实进入 `docs/` 前必须确认仍然有效。
