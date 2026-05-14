# FFmpeg 命令构造器完成日志

## Behavior Summary

实现 FFmpeg 命令构造器。该模块接收 `MediaTask`，根据任务目的、输出格式、编码器、分辨率和输出目录生成 `FfmpegCommandPlan`。

命令构造器只负责生成参数计划，不启动 FFmpeg，不解析进度，不写日志，不修改数据库和任务状态。

## Followed Plan Or Flowchart

遵循飞书最后一个白板中的 `FFmpeg 命令构造器` 流程图：

- 输入校验阶段
- 输出路径阶段
- 参数构造阶段
- 返回 / 异常阶段

## Modified Files

- `lib/infrastructure/providers/ffmpeg_provider.dart`
  - 新增 `ffmpegCommandBuilderProvider`，向后续执行器暴露命令构造器抽象。

## Added Files

- `lib/application/services/ffmpeg_command_builder.dart`
  - 定义 `FfmpegCommandPlan`、`FfmpegCommandBuildException` 和 `FfmpegCommandBuilder` 抽象接口。
- `lib/infrastructure/services/default_ffmpeg_command_builder.dart`
  - 实现当前默认命令构造规则，包括输出路径生成、文件名去重、压缩/转换参数、分辨率参数和通用输出参数。
- `test/ffmpeg_command_builder_test.dart`
  - 覆盖压缩命令、转换命令、默认输出目录、输出名去重、分辨率参数、非视频拒绝和暂不支持 VideoToolbox 的行为。

## Purpose Of Each Added File

- `ffmpeg_command_builder.dart`
  - 让后续执行器依赖稳定抽象，而不是直接依赖具体实现。
- `default_ffmpeg_command_builder.dart`
  - 把当前版本的 FFmpeg 参数规则集中管理，避免散落到 UI 或执行器里。
- `ffmpeg_command_builder_test.dart`
  - 固定命令构造器的关键业务规则，后续改参数时可以快速发现行为变化。

## Deleted Files

No deleted files.

## Unfinished Items Or User Confirmation Points

- VideoToolbox 暂未实现，当前会明确抛出“不支持”异常。
- 命令构造器暂不检查输出目录是否存在或是否可写，这部分留给后续执行器或设置模块处理。
- FFmpeg 执行、进度解析、日志落盘、任务状态流转还未实现。

## Validation Method Or Test Result

- 已运行：

```text
dart analyze lib/application/services/ffmpeg_command_builder.dart lib/infrastructure/services/default_ffmpeg_command_builder.dart lib/infrastructure/providers/ffmpeg_provider.dart test/ffmpeg_command_builder_test.dart
```

结果：

```text
No issues found!
```

- 已尝试运行：

```text
flutter test
```

结果：未能完成。当前 `sqlite3` 依赖的 native asset 需要从 GitHub 下载 `libsqlite3.arm64.macos.dylib`，网络连接超时，测试流程在依赖下载阶段失败，尚未进入测试用例执行。
