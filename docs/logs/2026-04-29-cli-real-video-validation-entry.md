# 简易 CLI 真实视频链路验证入口完成日志

## Behavior Summary

新增一个开发验证用 CLI，用来在 UI 完成前验证真实视频的 FFmpeg 主链路。

当前 CLI 第一版只支持单文件压缩：

```text
dart run tool/machining_cli.dart compress <input-video>
```

执行流程：

- 检查命令和输入文件。
- 解析本机 `ffmpeg` / `ffprobe` 运行时。
- 调用 FFprobe 读取媒体信息。
- 创建临时 `MediaTask`。
- 调用 `DefaultFfmpegCommandBuilder` 生成 FFmpeg 命令计划。
- 启动 FFmpeg 进程。
- 复用 `LocalFfmpegProcessObserver` 解析 stdout 进度，并把 stderr 写入原始日志。
- 根据 FFmpeg 退出结果和输出文件存在性打印 `completed` 或 `failed`。

该 CLI 不接 UI，也不接数据库队列。它只编排现有应用服务，用于验证底层能力是否真实可用。

## Followed Plan Or Flowchart

遵循飞书最后一个白板 `简易CLI - 核心功能测试` 中的流程图：

- 设计约束
- 命令入口阶段
- 运行时检查阶段
- 媒体分析阶段
- 命令构造阶段
- 执行观测阶段
- 结果校验阶段

## Modified Files

- `docs/log.md`
  - 追加本次 CLI 开发验证入口的总日志索引。

## Added Files

- `tool/machining_cli.dart`
- `docs/logs/2026-04-29-cli-real-video-validation-entry.md`

## Purpose Of Each Added File

- `tool/machining_cli.dart`
  - 提供开发验证用 CLI 入口，复用现有 FFprobe / FFmpeg 服务跑真实视频压缩链路。
- `docs/logs/2026-04-29-cli-real-video-validation-entry.md`
  - 记录 CLI 的实现边界、验证方式和后续未完成事项。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- 还没有使用真实视频样片执行完整压缩验证。
- 当前 CLI 只支持 `compress`，还不支持 `convert`、`batch`、`--output-dir`、`--crf`、`--preset`。
- 当前 CLI 是开发验证工具，放在 Dart / Flutter 常用的 `tool/` 目录中；如果后续要做成正式命令行产品，再迁移到 `bin/` 或独立 CLI package。
- 当前 CLI 不接数据库，所以不会持久化任务状态；这是为了避免和 UI / 队列状态过早耦合。

## Validation Method Or Test Result

已运行：

```text
dart format tool/machining_cli.dart
```

结果：格式化通过。

已运行：

```text
flutter analyze tool/machining_cli.dart
flutter analyze
```

结果：

```text
No issues found!
```

已运行：

```text
dart run tool/machining_cli.dart --help
```

结果：CLI 正常打印用法。

已运行：

```text
dart run tool/machining_cli.dart compress /tmp/not-exist-machining-demo.mp4
```

结果：正确进入输入文件缺失分支并返回错误码。

已运行：

```text
flutter test
```

结果：

```text
All tests passed!
```
