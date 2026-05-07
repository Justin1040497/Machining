# 2026-05-07 Windows Runtime Packaging Fixes

## Problem Summary

Windows 端试运行时发现三个问题：

1. 发布产物中没有内置 `ffmpeg.exe` / `ffprobe.exe`。
2. 窗口没有最小尺寸限制，缩小后工作台布局会被压坏。
3. 左侧任务列表读取失败，错误信息显示无法加载 `sqlite3.dll`。

任务列表错误示例：

```text
Invalid argument(s): Couldn't resolve native function 'sqlite3_initialize'
Failed to load dynamic library 'sqlite3.dll'
The specified module could not be found. (error code: 126)
```

## Root Cause

### Windows FFmpeg Runtime

macOS 已经有 Xcode build phase 负责复制内置 FFmpeg，但 Windows CMake 之前没有对应逻辑。

应用的 Dart 运行时查找器已经支持：

```text
<exe directory>/ffmpeg/ffmpeg.exe
<exe directory>/ffmpeg/ffprobe.exe
```

但构建产物中没有把 `third_party/ffmpeg/windows-x64` 下的二进制复制进去。

### Window Minimum Size

Windows Runner 使用 Flutter 默认窗口模板，没有处理 `WM_GETMINMAXINFO`，因此用户可以把窗口缩到小于当前工作台布局可承载的尺寸。

### SQLite On Windows

项目之前使用：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
```

这能避免 macOS 测试阶段从 GitHub 下载 sqlite3 native asset，但在 Windows 上默认会尝试加载 `sqlite3.dll`。Windows 系统通常自带的是 `winsqlite3.dll`，不是 `sqlite3.dll`，因此数据库初始化失败。

## Fix

### Bundle Windows FFmpeg

在 `windows/CMakeLists.txt` 中增加 Windows FFmpeg 复制规则。

约定本地二进制放置位置：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

构建时复制到：

```text
<machining.exe directory>/ffmpeg/
```

如果缺少这两个文件，Windows 构建直接失败，避免生成没有内置 FFmpeg 的发布包。

### Add Windows Runtime README And Ignore Rules

新增 `third_party/ffmpeg/windows-x64/README.md` 说明 Windows FFmpeg 放置规则。

`.gitignore` 只忽略 Windows FFmpeg 二进制：

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

目录和 README 会保留在仓库中。

### Configure SQLite System Library Name

保留系统 SQLite 策略，但为 Windows 指定库名：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
      name: sqlite3
      name_windows: winsqlite3
```

这样：

- macOS / Linux 继续使用 `sqlite3` 系统库。
- Windows 使用系统自带的 `winsqlite3.dll`。
- macOS 测试仍避免下载 GitHub sqlite3 native asset。

### Add Windows Minimum Window Size

在 `windows/runner/win32_window.cpp` 中处理 `WM_GETMINMAXINFO`。

最小逻辑尺寸：

```text
1216 x 893
```

在 150% Windows 缩放下约等于：

```text
1824 x 1340 physical pixels
```

该尺寸参考 Windows 端实测截图中的 `1823 x 1339 px`。

默认启动尺寸也调整为：

```text
1216 x 893
```

## Modified Files

- `.gitignore`
- `README.md`
- `pubspec.yaml`
- `windows/CMakeLists.txt`
- `windows/runner/main.cpp`
- `windows/runner/win32_window.cpp`

## Added Files

- `third_party/ffmpeg/windows-x64/README.md`
- `docs/logs/2026-05-07-windows-runtime-packaging-fixes.md`

## Deleted Files

No deleted files.

## Windows Build Notes

Before building on Windows, place the runtime files at:

```text
third_party\ffmpeg\windows-x64\ffmpeg.exe
third_party\ffmpeg\windows-x64\ffprobe.exe
```

Then run:

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

Expected output files:

```text
build\windows\x64\runner\Release\ffmpeg\ffmpeg.exe
build\windows\x64\runner\Release\ffmpeg\ffprobe.exe
```

## Validation Method Or Test Result

On macOS development machine:

```text
flutter pub get
flutter analyze
flutter test
```

Results:

```text
flutter pub get: passed
flutter analyze: No issues found
flutter test: 40 tests passed
```

Windows native build still needs to be verified on the Windows machine because macOS cannot run `flutter build windows`.
