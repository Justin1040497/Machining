# FFmpeg 许可与分发 v1.0

## 当前选择

Machining 1.0 内置 FFmpeg 7.1.1，并启用 x264 / libx264。因此发布包需要按 GPL 路线处理。

当前构建脚本启用：

```text
--enable-gpl
--enable-version3
--enable-libx264
--enable-videotoolbox
--enable-audiotoolbox
--disable-shared
--enable-static
--disable-sdl2
--disable-ffplay
--disable-doc
--disable-debug
```

`--enable-nonfree` 未启用。

## 仓库策略

不提交 FFmpeg / FFprobe 二进制：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
```

提交以下说明和元数据：

```text
third_party/ffmpeg/macos-arm64/README.md
third_party/ffmpeg/macos-arm64/ffmpeg-build-info.txt
scripts/build_ffmpeg_macos_arm64.sh
```

## 构建要求

构建前安装：

```bash
brew install nasm pkg-config
```

构建：

```bash
scripts/build_ffmpeg_macos_arm64.sh
```

脚本必须通过两个自检：

```text
OK: no Homebrew dynamic library dependencies detected
OK: libx264 encoder is available
```

## 发布要求

如果公开分发包含 FFmpeg + x264 的 app，需要至少准备：

- Machining 源码
- FFmpeg 和 x264 的源码获取方式
- FFmpeg 构建脚本和配置参数
- GPLv3 许可证文本
- FFmpeg / x264 的版权说明
- 用户能够替换或重新构建运行时的说明

## 1.0 状态

当前项目已经完成本地可分发运行时构建和 Release app 内置验证，但尚未完成正式公开发布所需的签名、公证、DMG 和许可证文件打包。因此 1.0 可以作为本地使用版本，正式发布动作进入 1.1。

## 1.1 待办

- 增加 `LICENSE`
- 增加 `THIRD_PARTY_NOTICES`
- 增加 Release 包内许可证目录
- 形成 DMG 分发结构
- 补充源码分发说明
- 验证另一台 Mac 上的运行和 Gatekeeper 行为
