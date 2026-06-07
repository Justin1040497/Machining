# Windows 运行时和发布包布局

## 所属版本

`v1.1.0`

## 当前事实

Windows x64 成为主要验证和发布平台之一。Release 目录必须包含 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe`，发布 zip 解压后必须有稳定顶层目录。

## 设计方式

- `windows/CMakeLists.txt` 在构建时复制 FFmpeg / FFprobe 到应用同级 `ffmpeg/` 目录。
- 如果 `third_party/ffmpeg/windows-x64/ffmpeg.exe` 或 `ffprobe.exe` 缺失，Release 构建失败。
- Windows 发布脚本逐文件写入 zip，并校验标准 `/` 路径分隔符和关键文件布局。
- GitHub Actions Windows workflow 可恢复运行时并调用发布脚本生成 zip。

## 为什么这样设计

Windows 用户不应依赖系统 PATH 中的 FFmpeg。发布包内部布局必须和运行时定位逻辑一致，否则应用会启动但处理任务失败。

## 设计收益

- 避免发布出缺少 FFmpeg 的 Windows 包。
- 避免 zip 内反斜杠条目导致解压布局异常。
- CI 可以验证 Windows 发布链路。

## 关联经验

- `docs/lessons.md#Windows zip 条目路径要强制使用标准分隔符`
