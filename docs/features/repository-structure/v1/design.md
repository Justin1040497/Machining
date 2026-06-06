---
module: repository-structure
version: v1
date: 2026-06-06
tags: [architecture, repository, workflow, tooling]
---

# repository-structure — 设计报告

## 1. 目标

整理 FrameLean 仓库根目录，让源码、平台工程、文档、三方运行时、许可证、脚本、测试样本和本地临时材料各有明确位置。

本次目标不是把 Flutter 项目改成 monorepo，也不是重写构建系统。当前 Flutter 工程仍以仓库根目录作为 app 根，因为 `pubspec.yaml`、`lib/`、`test/`、`macos/`、`windows/`、`linux/` 是 Flutter 工具链默认识别结构。把桌面端整体移动到 `apps/desktop/` 会牵动平台工程、脚本、CI、路径解析和发布流程，应作为后续大型迁移单独评估。

## 2. 现状分析

当前根目录混在一起的内容主要有：

- Flutter 标准工程目录：`lib/`、`test/`、`assets/`、`macos/`、`windows/`、`linux/`。
- 项目文档和工作流：`docs/`、`.agents/`、`AGENTS.md`、`CLAUDE.md`。
- 构建和开发工具：`scripts/`、`tool/`、`.github/`。
- 三方运行时和分发材料：`third_party/`、`legal/`、`LICENSE`、`legal/NOTICE.md`。
- 本地参考和临时材料：`.reference/`、`tmp/`、`worktrees/`、`.folderslice.assetmeta/`。
- IDE 和系统痕迹：`.idea/`、`.vscode/`、`.DS_Store`。

问题不在于目录数量，而在于根目录缺少“哪些是产品源码、哪些是可分发运行时、哪些是本地工作区材料”的边界。尤其是 `.reference/`、`tmp/`、`.folderslice.assetmeta/` 这类本地材料即使被 `.gitignore` 忽略，也会让工作区视觉上很乱。迁移前 `.folderslice.assetmeta/` 出现在已跟踪文件列表中，本轮重构将其内容保留到 ignored 的 `.workspace/tool-state/folderslice/`，并从版本库移出。

## 3. 目标根目录

首阶段建议保持 Flutter 根工程结构，只做治理和归位：

```text
FrameLean/
  AGENTS.md
  CLAUDE.md
  README.md
  LICENSE
  pubspec.yaml
  pubspec.lock
  analysis_options.yaml
  devtools_options.yaml

  .agents/                 项目级 agent workflow 和 skills
  .github/                 CI / GitHub workflow

  assets/                  应用静态资源：图标、字体、图片
  docs/                    当前文档、功能设计、开发流程和历史记录
  legal/                   分发许可证、source offer、third-party notices

  lib/                     Flutter / Dart 应用源码
  test/                    自动化测试；小型 fixture 放在 test/fixtures/
  macos/                   Flutter macOS 平台工程
  windows/                 Flutter Windows 平台工程
  linux/                   Flutter Linux 平台工程

  scripts/                 人工执行的构建、发布和维护脚本
    build/
    release/
    dev/

  tool/                    Dart 开发工具和项目 CLI
  third_party/             会进入发布链路或需要可追溯的三方运行时
    ffmpeg/
    audio_adapters/        仅当 QMC 等外部适配器实际接入时创建

  .workspace/              本地工作区材料，整体 ignored，不进入版本库
    references/
    samples/
    tmp/
    worktrees/
```

### 3.1 保留在根目录的内容

这些目录或文件与 Flutter 工具链、平台构建或项目入口直接相关，不建议首阶段移动：

| 路径 | 原因 |
| --- | --- |
| `pubspec.yaml`、`pubspec.lock` | Flutter / Dart 包根，移动成本高 |
| `lib/`、`test/`、`assets/` | Flutter 默认源码、测试和资源目录 |
| `macos/`、`windows/`、`linux/` | Flutter 平台工程目录，构建脚本和插件注册依赖这些位置 |
| `.github/` | CI 入口，根目录位置符合 GitHub 约定 |
| `.agents/`、`AGENTS.md`、`CLAUDE.md` | 项目级 agent 工作流入口 |
| `docs/` | 项目文档中心，现有 `docs/README.md` 已定义文档地图 |
| `legal/`、`third_party/` | 分发、许可证和三方运行时需要保留清晰顶层入口 |

### 3.2 迁入 `.workspace/` 的内容

这些内容是本地工作材料，不应散落在根目录：

| 当前路径 | 目标路径 | 处理 |
| --- | --- | --- |
| `.reference/` | `.workspace/references/` | 本地参考仓库和源码快照，不进入版本库 |
| `tmp/` | `.workspace/tmp/` | 临时输出、测试视频、手动验证产物，不进入版本库 |
| `worktrees/` | `.workspace/worktrees/` | 保持根目录干净，迁入 `.workspace/` |
| `.folderslice.assetmeta/` | `.workspace/tool-state/folderslice/` | 工具本地状态，不应跟踪；迁移前先确认是否需要保留数据库 |

`.workspace/` 应整体加入 `.gitignore`。如果仍想使用 `worktrees/` 作为 Git 工作树固定入口，也可以保留 `worktrees/`，但它必须保持 ignored。

### 3.3 `third_party/` 与 `legal/` 的边界

`third_party/` 放“运行时或构建时会用到的三方产物或可追溯材料”，例如 FFmpeg / FFprobe、后续可能存在的 QMC 外部适配器。它不是随手下载源码仓库的地方。

`legal/` 放“分发时必须带上的许可证和声明”，例如 GPL、source offer、third-party notices。`third_party/` 新增可分发产物时，必须同步 `legal/third-party/` 和 `docs/reference/`。

建议规则：

- `third_party/ffmpeg/` 保留当前结构。
- 后续外部音频适配器使用 `third_party/audio_adapters/{adapter}/{platform}/`。
- 不把完整第三方源码仓库直接放进 `third_party/`；源码参考放 `.workspace/references/`，许可证和构建说明进入 `legal/` / `docs/reference/`。

### 3.4 `scripts/` 与 `tool/` 的边界

`scripts/` 放 shell / PowerShell 这类人工执行脚本，按用途拆分：

```text
scripts/
  build/
    build_ffmpeg_macos_arm64.sh
  release/
    build_dmg_macos.sh
    build_windows.ps1
  dev/
```

`tool/` 放 Dart 开发工具、项目 CLI、代码生成辅助入口，例如当前 `tool/framelean_cli.dart`。

迁移脚本时必须同步所有文档、CI、release runbook 和手动命令，避免脚本移动后构建说明失效。

### 3.5 测试样本和手动样本

小型、可公开、稳定的自动化测试样本放：

```text
test/fixtures/
  media/
  proprietary_audio/
```

大型视频、真实音乐文件、用户本地样本和版权不清晰样本放：

```text
.workspace/samples/
```

自动化测试不能依赖 `.workspace/samples/`。如果 NCM 需要端到端样本，优先使用可生成的最小 fixture 或受控小样本，不把真实用户音乐文件提交进仓库。

## 4. 迁移顺序

第一阶段只做低风险根目录治理：

1. 新增 `.workspace/` 规则到 `.gitignore`。
2. 把 `.reference/` 和 `tmp/` 的使用约定改为 `.workspace/references/`、`.workspace/tmp/`，不移动用户未确认要保留的大文件。
3. 确认 `.folderslice.assetmeta/` 是否为本地工具状态；确认后从版本库移除跟踪并保留 ignored。
4. 新建 `test/fixtures/` 规范，只放小型自动化 fixture。
5. 更新 `docs/README.md` 和 `docs/develop/architecture.md` 的目录说明。

第二阶段整理工程脚本：

1. 创建 `scripts/build/`、`scripts/release/`、`scripts/dev/`。
2. 将现有脚本移动为 `scripts/build/build_ffmpeg_macos_arm64.sh`、`scripts/release/build_dmg_macos.sh`、`scripts/release/build_windows.ps1`。
3. 更新文档和任何 CI / release 引用。
4. 跑 `flutter analyze`、`flutter test`，并手动校验脚本路径。

第三阶段只在需要 monorepo 时评估：

```text
apps/
  desktop/
server/
packages/
```

这会把当前 Flutter 根工程移动到 `apps/desktop/`，属于高成本迁移。只有当 FrameLean 后端、共享包、发布管线和多应用结构都明确长期存在时，才值得做。

## 5. 验收标准

| 验收条件 | 验收方式 |
| --- | --- |
| 根目录能一眼区分源码、文档、平台工程、三方运行时、本地材料 | 人工审查 `find . -maxdepth 2` 输出 |
| 本地参考仓库和临时样本不出现在版本库候选中 | `git status --short` 不显示 `.workspace/`、`.reference/`、`tmp/` |
| `.folderslice.assetmeta/` 不再作为项目文件跟踪 | `git ls-files '.folderslice.assetmeta/*'` 为空 |
| 脚本移动后文档命令仍正确 | 按文档执行对应构建或 dry-run 校验 |
| Flutter 工具链不受影响 | `flutter analyze` 和 `flutter test` 通过 |
| 第三方运行时和许可证边界清晰 | `third_party/`、`legal/`、`docs/reference/` 互相对应 |

## 6. 暂不实现

| 功能 | 理由 | 是否预留扩展 |
| --- | --- | --- |
| 立刻迁移到 `apps/desktop/` monorepo | 当前主要是桌面 Flutter app，迁移成本明显高于收益 | 是 |
| 把 Flutter 平台目录移动到子目录 | 会破坏 Flutter 默认工程结构和脚本路径 | 否 |
| 删除本地参考仓库和样本 | 可能包含用户仍要查看的材料，需确认后处理 | 是 |
| 提交大型真实媒体样本 | 仓库体积、版权和隐私风险高 | 否 |
| 把完整三方源码仓库提交到 `third_party/` | 不利于许可证和更新边界管理 | 否 |
