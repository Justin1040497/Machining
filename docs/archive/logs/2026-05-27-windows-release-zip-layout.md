# 2026-05-27 Windows Release Zip Layout

## Problem Summary

GitHub Actions 生成的 Windows 发布包下载后，在 Windows 测试中显示 FFmpeg 不可用。

## Root Cause

发布 zip 内部条目使用了 Windows 反斜杠路径，例如 `ffmpeg\ffmpeg.exe`。应用运行时查找的是 `FrameLean.exe` 同级目录下的 `ffmpeg/ffmpeg.exe` 和 `ffmpeg/ffprobe.exe`。这种 zip 布局在不同解压器下可能不能稳定还原为真实目录，导致内置 FFmpeg 路径解析失败。

## Fix

Windows 打包脚本不再直接使用 `Compress-Archive -Path Release\*`。脚本现在逐个文件写入 zip，并将 entry name 统一转换为 `/` 分隔的标准 zip 路径。打包后会校验 zip 中不能存在反斜杠条目，并必须包含 `ffmpeg/ffmpeg.exe`、`ffmpeg/ffprobe.exe`、`FrameLean.exe`、`data/app.so` 和法律资料。

GitHub Actions 首次验证暴露出 Windows runner 的 PowerShell 没有自动加载 `System.IO.Compression.ZipArchiveMode` 所在程序集，因此脚本也显式加载 `System.IO.Compression` 和 `System.IO.Compression.FileSystem`。

## Modified Files

- `scripts/build_windows.ps1`
- `docs/archive/changelog.md`

## Validation

- `unzip -l /Users/leftzhou/Downloads/FrameLean-v1.0.0-windows-x64.zip`
- GitHub Actions 日志：`Unable to find type [System.IO.Compression.ZipArchiveMode]`
- `git diff --check`

## Notes

当前 macOS 环境没有 `pwsh`，无法在本机直接执行 Windows PowerShell 打包脚本；需要由 GitHub Actions 的 Windows runner 重新打包验证。
