# FrameLean Skills 使用说明

本目录保存只服务 FrameLean 仓库的项目级 skills。

## 项目规则

- Skill 位于 `.agents/skills/framelean-*`，使用小写连字符命名。
- 新增、删除、合并或重命名后，同步更新本文件和 `framelean-workflow/SKILL.md`。
- 临时计划和验证报告放入 ignored 的根 `.workspace/`；正式发布记录进入 `docs/releases/<component>/`，开发过程和技术变化进入 `changelog/<component>.md`。
- 不创建 skill 级 README、CHANGELOG、安装说明或过程记录，也不复制用户级 Skill。

## 共享预读协议

按需递增读取，避免每次加载全部文档。

1. 先应用根 `AGENTS.md`。跨组件任务读取根 `CONTEXT.md`、`docs/README.md` 和相关 `context/`；单组件任务不默认加载全部根文档。
2. 按下表读取目标组件最小事实集，再用 `rg` 定位相关源码、测试、脚本和配置：

| 范围 | 默认事实源 | 按需追加 |
| --- | --- | --- |
| Desktop Client | `desktop-client/README.md`、`desktop-client/CONTEXT.md`、`desktop-client/pubspec.yaml`、`desktop-client/docs/develop/workflow.md` | `desktop-client/docs/develop/`、`desktop-client/docs/decisions/`、源码与测试 |
| Backend | `backend/README.md`、`backend/CONTEXT.md`、`backend/pom.xml` | `backend/admin-web/package.json`、目标 Maven module、Docker 与配置 |
| FLL | `fll/README.md`、`fll/CONTEXT.md`、`fll/Cargo.toml` | 目标 crate manifest/source、`fll/docs/`、`fll/schemas/`、Engine 架构 Skills |
| FEngine | `fengine/README.md`、`fengine/CONTEXT.md`、`fengine/Cargo.toml` | `fengine/src/`、FLL 公开 API、Engine 架构 Skill |
| Protocol | `protocol/README.md`、`protocol/v1/README.md`、`context/protocol.md` | 对应职责索引；Runtime Schema 事实回到 FLL |
| 构建、CI、发布 | `scripts/README.md`、目标 workflow 与实际脚本 | `installer/`、`tools/`、`legal/` 和组件 manifest |

3. 正式发布历史只从 `docs/releases/<component>/` 读取；开发过程和技术变化只从 `changelog/<component>.md` 读取。Desktop 专用决策、工作状态和经验保留在 `desktop-client/docs/`，跨组件决策入口位于根 `docs/decisions/`。
4. 实现、验证、交付和 Skill 维护前读取 Git status 并保护全部未提交内容；只有任务依赖版本范围或历史事实时才读取 log、tag 和远端状态。
5. 文档与实现冲突时，以 manifest、源码、测试、脚本和配置验证当前事实，同时修正过时的当前事实文档；不得用目标架构覆盖尚未实现的能力。

## 临时工作区

```text
.workspace/
  plans/YYMMDD-feature-slug.md
  release-drafts/vX.Y.Z.md
  architecture-reference/
  validation/
```

临时文件不进入版本库；稳定事实由交付或发布流程写入正式文档。外部参考项目、竞品比较和不可上传的研究材料只能保存在 `.workspace/`，不得由受跟踪文件链接或复制进 Git。

## Skill 路由

| 用户意图 | Skill |
| --- | --- |
| 不确定使用哪个 Skill，或要求跨阶段完整流程 | `framelean-workflow` |
| 分析需求、现有功能、交互、依赖和边界 | `framelean-feature-analysis` |
| 比较方案、划定范围、拆分任务和验证边界 | `framelean-feature-plan` |
| 实现已确认的代码、测试、脚本、文档或 Skill 变更 | `framelean-implementation` |
| 按组件制定验证范围、审查 tracked/untracked 变化、运行检查和解释失败 | `framelean-validation` |
| 校准受影响事实，准备 commit 信息和精简 PR 描述 | `framelean-delivery` |
| 为指定组件和版本产出面向用户的精简 release 文档 | `framelean-release` |
| 为 Desktop Client 当前或指定版本生成友好版本日志并保存到下载目录 | `framelean-user-changelog` |
| 创建、合并、删除或重构项目级 Skills | `framelean-skill-create` |
| 判断 FLL 核心处理库、FEngine 进程宿主、Cargo DAG 和组装边界 | `framelean-engine-architecture` |
| 判断媒体阶段、Processor、Pipeline 数据流和插件边界 | `framelean-media-pipeline` |

常规完整流程为：分析 → 计划 → 实现 → 验证 → 交付。正式发布文档独立使用 `framelean-release`，软件内版本日志使用 `framelean-user-changelog`；Skill 维护使用 `framelean-skill-create` 后进入实现和验证。

## 共同底线

- 先核对真实项目状态，再更新文档。
- 不在 `main` 上直接做日常开发改动。
- 不处理无关用户改动，不擅自 stage、commit、push、revert 或发布。
- 不创建 `docs/archive/`、`docs/features/`、`docs/plans/` 或 `docs/product/roadmap.md`。
- 不创建假能力、空 crate 或仅为目标目录占位的模块；FLL 与 FEngine 保持独立 Cargo 工程。
- Pipeline 不依赖 Plugin，Plugin 不依赖 Pipeline；两者只在 Runtime 内部组合。
- FLL 是核心处理库；FEngine 是独立引擎进程和进程级管理边界。当前 FEngine 已实现长度帧 JSON Worker、受 token 保护的本机 loopback 守护连接、独立分析/执行队列、会话幂等、Snapshot 对账和执行控制；FLL Runtime 已支持真实 libav stream-copy/remux、单 lane LIFO 调度和输出事务。需要 Decoder、Encoder 或 Processor 的完整转码链仍必须 fail closed。
- FEngine 不绕过 FLL Runtime 修改 Task 状态；进程通信、监督或会话能力只在存在真实实现时建立。
- Backend 只按实际 `backend/pom.xml` modules 工作，不重命名、提升或合并现有 `ruoyi-*` 模块。
- `protocol/v1` 记录当前 Client/FEngine transport、命令、职责和兼容边界；wire model 位于 `fengine/src/protocol.rs`，Runtime Schema 的代码源头与基线继续位于 FLL。
- `dependencies/` 保存可跟踪的第三方源码、许可证和构建输入；可重建二进制只进入被忽略的 `build/dependencies/`。
