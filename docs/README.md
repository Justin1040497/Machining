# FrameLean 文档入口

这个目录只保存当前仍有阅读价值的项目文档。项目背景和当前上下文在根目录 `CONTEXT.md`；版本变更摘要在根目录 `CHANGELOG.md`。

## 文档地图

```text
docs/
  README.md

  work/
    active.md                 当前正在推进的任务，保持 1 页以内
    backlog.md                候选任务池，表格化维护
    decisions.md              仍有效的重要决策索引

  releases/
    vX.Y.Z/                   按发行版本记录事实设计说明

  decisions/
    YYMMDD-summary.md         重要决策正文

  develop/
    architecture.md           当前架构事实
    data-model.md             当前数据模型事实
    technology-stack.md       当前技术栈和平台边界
    test-plan.md              当前测试和验证范围
    workflow.md               需求、分支、测试、实现、验证、提交、PR 和发布流程

  reference/
    ffmpeg-license-distribution.md
    third-party-audio-adapters.md

  lessons.md                  踩坑记录和经验总结
```

## 阅读顺序

1. 快速理解项目：读根目录 `CONTEXT.md`。
2. 看当前正在做什么：读 `work/active.md`。
3. 看候选任务池：读 `work/backlog.md`。
4. 理解某个版本形成了什么能力：读 `releases/vX.Y.Z/`。
5. 理解为什么做某个重要选择：读 `work/decisions.md`，再跳到 `decisions/` 正文。
6. 避免重复踩坑：读 `lessons.md`。
7. 准备改代码：按范围读 `develop/architecture.md`、`develop/data-model.md`、`develop/test-plan.md` 和 `develop/workflow.md`。
8. 准备调用 FrameLean 项目级 skills：读 `.agents/skills/README.md` 的路由和共享预读协议。

## 维护规则

- 不再创建 `docs/archive/`、`docs/features/`、`docs/plans/` 或 `docs/product/roadmap.md`。
- 不写每日日志。
- 小 bug 修复不单独建文档；可复用经验写进 `lessons.md`。
- 重要决策使用 `docs/decisions/YYMMDD-summary.md`。
- 当前任务写进 `docs/work/active.md`，候选任务写进 `docs/work/backlog.md`。
- 稳定版本事实写进 `docs/releases/vX.Y.Z/`，不记录执行期任务清单。
- `CHANGELOG.md` 只记录版本级变化摘要。
