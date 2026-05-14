# SQLite3 Native Assets 下载超时修复日志

## Problem Summary

运行 `flutter test test/ffmpeg_task_queue_runner_test.dart` 时，测试没有进入用例执行阶段，而是在 `sqlite3` 的 native assets 构建阶段失败。

失败原因是 `package:sqlite3` 默认会从 GitHub release 下载预编译 SQLite 动态库：

```text
https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.3.1/libsqlite3.arm64.macos.dylib
```

即使本机已经配置代理环境变量，Flutter / Dart hook 运行阶段仍然出现连接 GitHub 超时：

```text
SocketException: Operation timed out
address = github.com
```

## Root Cause

该问题发生在 Flutter native assets hook 构建阶段，不是测试代码本身失败。

`sqlite3` 依赖默认使用 GitHub release 中的预编译动态库。这个下载路径依赖外部网络，并且在当前环境中不稳定，导致 `flutter test` 被阻塞在依赖构建阶段。

## Fix

根据 `sqlite3` 官方 hook 文档，改为使用系统提供的 SQLite 动态库，避免测试阶段下载 GitHub release 资源。

修改 `pubspec.yaml`：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
```

含义：

- `sqlite3` 不再下载包内预编译 SQLite 动态库。
- 测试和本机运行使用操作系统提供的 SQLite。
- 当前 macOS 开发环境可以直接通过系统库满足测试需求。

## Modified Files

- `pubspec.yaml`
  - 新增 `hooks.user_defines.sqlite3.source = system`。

## Added Files

- `docs/archive/logs/2026-04-29-sqlite3-native-assets-system-library.md`
  - 记录 sqlite3 native assets 下载超时的原因、解决方式和验证结果。

## Deleted Files

No deleted files.

## Validation Method Or Test Result

已运行：

```text
flutter test test/ffmpeg_task_queue_runner_test.dart
```

结果：

```text
00:00 +8: All tests passed!
```

## Notes

该修复是本地开发和测试环境的稳定性修复。后续如果要打包分发，需要再结合目标平台确认 SQLite 动态库来源策略：

- 开发 / 测试：可以继续使用 `source: system`。
- 正式分发：需要评估是否继续使用系统 SQLite，或改为随应用打包 SQLite 动态库。
