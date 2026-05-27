# 2026-05-27 Windows Open File Location

## Problem Summary

Windows 上点击“打开文件所在位置”时，如果输出路径包含空格、中文或其他需要转义的字符，Explorer 可能无法正确解析目标文件路径，并导致应用提示打开失败。

受影响入口都汇聚到同一个文件位置打开逻辑：

- 压缩完成弹窗里的“打开文件所在位置”。
- 任务详情弹窗里的“打开源文件所在位置”。
- 任务右键菜单里的“打开文件所在位置”。

## Root Cause

Windows 分支原先把 Explorer 的选择开关和目标路径拼成同一个参数：

```text
/select,C:\Users\left\Videos\第二节课 实操.mp4
```

当路径包含空格或中文时，Dart 在 Windows 上构造进程命令行时可能把整个参数一起引用。Explorer 更稳定的命令形态是让 `/select,` 保持为未被整体引用的独立开关，再把目标路径作为单独参数传入。

## Fix

集中修复 `WorkbenchFileRevealer`：

- 将跨平台文件管理器命令构造拆成可测试的 `buildRevealCommand()`。
- Windows 文件定位改为 `explorer.exe`，参数为 `['/select,', targetPath]`。
- Windows 改为 detached 启动 Explorer，路径存在性由应用先校验，避免 Explorer 进程退出码造成误报。
- Windows 目录目标改为直接打开目录。
- macOS 文件继续使用 `open -R`，目录目标改为直接打开目录。
- Linux 文件继续打开父目录，目录目标直接打开目录。
- 当目标文件不存在但父目录存在时，回退打开父目录。
- 当系统命令失败但 `stderr` 为空时，错误提示会回退显示 `stdout` 或退出码。

## Modified Files

- `lib/features/workbench/pages/workbench_page/workbench_file_revealer.dart`
- `test/workbench_file_revealer_test.dart`
- `docs/develop/test-plan.md`
- `docs/archive/changelog.md`

## Validation

- `dart format lib/features/workbench/pages/workbench_page/workbench_file_revealer.dart test/workbench_file_revealer_test.dart`
- `flutter test test/workbench_file_revealer_test.dart`
- `flutter analyze`

## Remaining Confirmation

- 当前环境是 macOS，已完成命令构造单元测试和静态分析。
- 仍建议在 Windows 机器上用包含空格和中文的真实输出路径手动点击“打开文件所在位置”，确认 Explorer 能定位到目标文件。
