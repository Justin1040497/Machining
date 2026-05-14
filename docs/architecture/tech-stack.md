# 技术栈与开发环境

## 文档目的

这份文档记录 Machining 当前使用的开发环境、框架、核心依赖和技术边界。

它同时面向开发者和 AI：

1. 开发者可以快速确认项目需要哪些基础环境。
2. AI 可以先阅读本文件，减少对生成目录和平台目录的重复扫描。
3. 后续引入新依赖或调整技术方案时，可以在这里同步更新项目事实。

## 状态说明

| 状态 | 含义 |
| --- | --- |
| 已使用 | 已经写入项目配置或源码，并且当前项目正在使用 |
| 计划使用 | 已有明确方向，但还没有正式落地 |
| 候选方案 | 可以考虑，但尚未决定 |

AI 在理解项目时，应以“已使用”为当前事实，不要把“计划使用”或“候选方案”当成已经完成的实现。

## 当前技术栈总览

| 模块 | 技术 | 当前状态 | 说明 |
| --- | --- | --- | --- |
| 桌面客户端 | Flutter | 已使用 | 当前主应用框架 |
| 客户端语言 | Dart | 已使用 | Flutter 项目语言 |
| 状态与业务分层 | Riverpod / Clean Architecture 风格分层 | 已使用 | 以现有代码结构为准 |
| 本地数据库 | Drift + SQLite | 已使用 | 保存任务和设置 |
| 媒体处理 | FFmpeg / FFprobe | 已使用 | 本地视频分析、预览和压缩 |
| macOS 打包 | Flutter macOS + Xcode 构建阶段 | 已使用 | Release app 内置 FFmpeg 运行时 |

## 项目目录

主要源码目录：

```text
lib/
  app/
  domain/
  application/
  infrastructure/
  features/
```

主要平台和工程目录：

```text
macos/
windows/
linux/
web/
test/
scripts/
third_party/
```

当前 1.0 只验证 macOS Apple Silicon 本地可用版本。其他平台目录来自 Flutter 工程结构，不代表已经完成跨平台发布。

## 核心依赖位置

Flutter 和 Dart 依赖声明位于：

```text
pubspec.yaml
```

FFmpeg 运行时说明位于：

```text
third_party/ffmpeg/macos-arm64/README.md
docs/reference/ffmpeg-license-and-distribution-v1.0.md
```

## 给 AI 的使用说明

AI 在处理代码任务时，应优先阅读：

1. `docs/product/README.md`
2. `docs/architecture/README.md`
3. `docs/architecture/data-model-v1.0.md`
4. 与任务相关的 `docs/features/<feature-name>/` 文档

不要把 `archive/` 中的历史日志直接当成当前实现事实。
