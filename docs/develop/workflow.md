# FrameLean 工作流

## 文档目的

这份文档合并 FrameLean 的项目执行、Git、提交、PR 和发布规则。它约束开发者和 AI agent 如何理解需求、准备分支、设计验证、实现、更新文档、准备提交和发布说明。

## 核心原则

- 先理解项目，再讨论方案；不能只读用户描述。
- 如果文档和当前代码不一致，并且代码已经明显推进到文档之后，以当前代码为准，同时更新文档。
- 如果代码偏离仍有效的架构或流程规则，需要指出风险。
- 非平凡需求需要先讨论需求、替代方案、风险、边界和验证方式。
- 实现必须严格服从已确认范围，不顺手扩大功能。
- `main` 是唯一长期主干，日常改动通过短生命周期分支和 PR / MR 合入。

## 执行阶段

### 1. 需求理解与方案讨论

开始前通常需要：

1. 阅读 `AGENTS.md`。
2. 阅读 `CONTEXT.md`、`docs/README.md` 和相关 `docs/` 文档。
3. 搜索并阅读相关源码、测试、脚本和配置。
4. 对比文档和项目实况，判断文档是否滞后。
5. 如果方案依赖框架、API、工具链或成熟产品做法，查阅官方文档或可信资料。

使用 FrameLean 项目级 skills 时，先按 `.agents/skills/README.md` 的共享预读协议读取项目事实，再递增读取领域文档、相关源码和 Git 事实。

讨论时需要说明方案长处、短板、风险、成本、测试难度和长期维护影响。

### 2. 分支或 worktree 准备

进入执行前确认 Git 状态：

```bash
git status --short
git branch --show-current
```

分支类型：

```text
feature/*
fix/*
chore/*
docs/*
release/*
hotfix/*
```

规则：

- 不在 `main` 上直接提交日常开发改动。
- 分支名使用小写英文、数字和短横线。
- 当前工作区有其他未完成改动时，优先使用 `.workspace/worktrees/<task-slug>` 创建独立 worktree。
- 新分支应基于最新远程 `main`；创建或打开分支后检查远程是否有新提交。

如果创建分支时报 `cannot lock ref`，先区分真实 ref 命名冲突和环境 / 沙盒写 `.git` 失败，不要反复更换有效分支名。

### 3. 测试与验证设计

写代码前先明确验证方式：

- bug 修复：设计复现测试或回归测试。
- 新功能：优先覆盖 domain、application use case 和关键 UI / widget 行为。
- 架构整理：先保护现有行为，再移动边界。
- 文档结构调整：检查路径引用、入口一致性和旧文档移除是否干净。
- 脚本和发布流程：验证命令、产物路径和关键文件布局。

### 4. 实现

规则：

- 不顺手增加未确认功能。
- 不做无关重构或大范围格式化。
- 遵循当前项目架构：`features -> application -> domain`，`infrastructure` 实现 application 抽象并依赖 domain。
- 优先复用项目已有 helper、provider、use case 和组件模式。
- 单文件不应无必要膨胀到 800 行以上；除非是生成文件、框架入口或强内聚库文件。

### 5. 审查与验证

Dart / Flutter 改动默认执行：

```bash
git ls-files '*.dart' | xargs dart format --set-exit-if-changed
flutter analyze
flutter test
```

根据范围追加：

- 构建脚本变更：执行对应脚本或做语法 / 产物结构验证。
- 打包变更：验证 macOS 或 Windows 产物中的关键运行时文件。
- CI 变更：验证 YAML 和 workflow 关键路径。
- UI 变更：进行手动检查或截图验证。
- 架构变更：检查依赖方向、测试覆盖和文档是否同步。
- 文档重构：运行路径引用扫描和 `git diff --check`。

### 6. 文档同步

当改动影响架构、数据模型、测试、发布流程、用户可见行为或开发者工作流时，必须更新文档。

文档入口：

- 项目上下文：`CONTEXT.md`
- 变更摘要：`CHANGELOG.md`
- 当前任务：`docs/work/active.md`
- 候选任务：`docs/work/backlog.md`
- 决策索引：`docs/work/decisions.md`
- 决策正文：`docs/decisions/YYMMDD-summary.md`
- 版本事实设计：`docs/releases/vX.Y.Z/*.md`
- 经验总结：`docs/lessons.md`
- 工程事实：`docs/develop/*.md`
- 项目级 skills：`.agents/skills/framelean-*`

不再创建每日日志或一 bug 一文档。bug 修复中的可复用经验写入 `docs/lessons.md`；若修复背后形成重要长期选择，写入 `docs/decisions/`。

## Changelog

提交准备前应更新根目录 `CHANGELOG.md`，记录本次值得回溯的版本级变化。

格式：

```text
YYYY-MM-DD｜vX.Y.Z｜Release 或 No Release
当天更新概要

### Added
### Changed
### Fixed
### Verified
```

`CHANGELOG.md` 只写摘要，不粘贴完整开发过程。

## Worktree

FrameLean 本地 worktree 统一放在：

```text
.workspace/worktrees/<task-name>
```

`.workspace/` 不进入版本库。常用命令：

```bash
git fetch origin
git worktree add .workspace/worktrees/example-task -b feature/example-task origin/main
git worktree list
git worktree remove .workspace/worktrees/example-task
git worktree prune
```

## 提交信息

推荐使用 Conventional Commits 风格：

| 前缀 | 含义 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `chore` | 工程治理 |
| `docs` | 文档 |
| `test` | 测试 |
| `refactor` | 重构 |
| `build` | 构建或依赖 |
| `ci` | CI 配置 |

推荐格式：

```text
<type>(scope): 中文摘要
```

## 提交详情输出

需求完成、文档同步、远端同步与验证完成后，交付包需要包含：

```markdown
## 提交详情

推荐提交：
`<type>(scope): 中文摘要`

提交范围：
- 文件或模块范围。

提交正文：
- 需要 / 不需要
- 原因：为什么需要或不需要。

建议正文：
仅在需要提交正文时填写；不需要时写 不适用。
```

## PR / MR 描述

PR / MR 标题建议沿用：

```text
<type>(scope): 中文摘要
```

description 固定使用：

```markdown
## 变更概览

## 背景与目标

## 实现详情

## 验证结果

## 风险与回滚

## 文档与变更记录

## 评审重点
```

不适用的段落保留标题并写 `无` 或 `不适用`。

## 发布规则

正式发布使用语义化 tag：

```text
v主版本.次版本.修订版本
```

发布包名称从 `pubspec.yaml` 的语义化版本读取，不包含 `+build` 后缀。例如 `version: 1.1.5+3`：

```text
FrameLean-v1.1.5.dmg（macOS Universal 2）
FrameLean-v1.1.5-windows-x64.zip
FrameLean-v1.1.5-windows-x64-setup.exe
```

Release description 固定使用：

```markdown
## 版本摘要

## 主要变更

## 验证与兼容

## 发布产物

## 已知风险

## 升级与回滚说明

## 关联记录
```

## 合并要求

每个 PR / MR 合并前至少确认：

- 分支从最新 `main` 创建，或已经同步最新 `main`。
- 改动范围和分支类型匹配。
- 没有混入无关格式化、生成文件或临时文件。
- 已运行必要检查。
- 如果改动影响用户行为，已补充或更新测试。
- 如果改动影响架构、测试、发布或使用方式，已同步更新文档。
