# FrameLean Skills 使用说明

本目录解释 FrameLean 这个项目的 skills。它们服务于当前仓库的需求分析、功能设计、任务拆解、测试计划、实现、审查验证和交付收尾。

如果需要创建或修改 FrameLean workflow 相关 skill，默认放在本目录：

```text
.agents/skills/
```

不要把这些项目级 skills 创建到 `/Users/leftzhou/.agents/skills` 或其他用户级目录，除非用户明确要求做成全局 skill。

## 总入口

优先使用 `framelean-workflow` 作为轻量路由入口。它只负责判断当前请求该交给哪个更小的 project skill，不再加载完整工作流细则。

适合使用 `framelean-workflow` 的情况：

- 用户说“走完整流程”。
- 用户不确定该用哪个 FrameLean skill。
- 请求横跨需求、设计、任务、测试、实现、验证、交付多个阶段。

如果用户请求很明确，直接使用对应的小 skill，避免无意义加载完整流程。

## Skill 路由表

| 用户意图 | 使用 skill | 主要产物 |
| --- | --- | --- |
| 分析功能、整理需求、梳理现有模块、写交互链/逻辑树/功能编号 | `framelean-feature-analysis` | `docs/features/{module}/{version}/analysis.md` |
| 写设计报告、比较方案、定义边界、提出分支名建议 | `framelean-feature-design` | `design.md` |
| 基于设计报告拆任务清单 | `framelean-feature-tasks` | `tasks.md` |
| 写测试计划/测试文档 | `framelean-test-plan` | `test.md` |
| 实现已确认的代码、测试、脚本或文档改动 | `framelean-implementation` | 源码、测试、脚本或文档变更 |
| 审查 diff、跑验证、解释失败、复验 | `framelean-review` | 验证结果和风险说明 |
| 生成 commit/PR/release 文案、更新 changelog、归档功能网、准备最终交付包 | `framelean-delivery` | 提交详情、PR 描述、Release description、归档记录 |

## 推荐完整流程

只有用户明确要求端到端推进时，才按完整链路执行：

1. `framelean-feature-analysis`
2. `framelean-feature-design`
3. `framelean-feature-tasks`
4. `framelean-test-plan`
5. 按 `docs/develop/git-workflow.md` 准备分支或 worktree
6. `framelean-implementation`
7. `framelean-review`
8. `framelean-delivery`

项目仍保留原有门禁：需求/设计/测试/实现等阶段之间，如果用户没有明确说 `可以`，不要擅自进入下一阶段；用户明确要求一次性完成的情况除外。

## 常见用法

### 只要 PR 或 commit 文案

使用 `framelean-delivery`，不要触发完整 workflow。

示例请求：

```text
用 $framelean-delivery 给当前改动写 commit 信息和 PR 描述
```

`framelean-delivery` 支持 brief mode：只读取 Git 状态、diff、相关模板和必要文件，不强制做功能网归档。

### 写功能设计报告

使用 `framelean-feature-design`。

设计报告必须给出 2-4 个分支名建议，例如：

```text
feature/<name>
fix/<name>
chore/<name>
docs/<name>
```

只提出建议，不直接创建分支；创建或切换分支仍要等用户确认。

### 写测试计划

使用 `framelean-test-plan`。

测试计划的主要来源是 `docs/develop/test-plan.md`、当前功能的 `analysis.md` / `design.md` / `tasks.md`、真实代码和现有测试。API 测试只是可选小节，只有当前功能真实涉及 HTTP/API/服务端接口时才展开。

### 审查和验证

使用 `framelean-review`。

它负责检查 diff 范围、架构边界、测试缺口，并按改动面运行或建议验证命令。交付文案不放在这个 skill 里。

### 功能网归档和最终交付

使用 `framelean-delivery` 的 archive mode。

适用场景：

- 用户要求“归档功能网”。
- 功能已经完成，需要整理 changelog、bug log、commit details、PR description。
- 任务涉及 release 分支、hotfix、tag、Release Notes、发布产物或分发流程，需要 release description。

## 文档位置约定

功能级文档使用：

```text
docs/features/{module}/{version}/analysis.md
docs/features/{module}/{version}/design.md
docs/features/{module}/{version}/tasks.md
docs/features/{module}/{version}/test.md
docs/features/feature-network/
```

这些文档服务于具体功能版本，不替代 `docs/develop/` 中的当前架构、测试、Git 和项目执行规则。

## 共同底线

- 先读 `AGENTS.md` 和相关项目文档。
- 不只依赖文档；需要检查真实源码、测试、脚本、配置和 Git 状态。
- 如果文档与代码冲突，只有在代码明显领先于旧文档时才以代码为准；否则要指出冲突。
- 不在 `main` 上直接做日常开发改动。
- 不 stage、commit、push、revert、delete 或格式化无关用户改动。
- 保持请求边界，不把小任务扩成完整流程。
