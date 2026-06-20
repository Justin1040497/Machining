# FFmpeg 许可与分发

## 当前选择

FrameLean 采用 `GPL-3.0-or-later` 作为项目整体开源许可证。项目内置 FFmpeg 7.1.1，并启用 x264 / libx264、LAME / libmp3lame、libwebp、Opus / libopus、zimg / libzimg、libvpx 和 SVT-AV1。因此包含该运行时的发布包需要按 GPLv3+ 路线处理。

当前构建脚本启用：

```text
--enable-gpl
--enable-version3
--enable-libx264
--enable-libmp3lame
--enable-libwebp
--enable-libopus
--enable-libzimg
--enable-libvpx
--enable-libsvtav1
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

仓库已经补齐基础许可资料。根目录保留 `LICENSE` 作为标准发现入口，完整发布法律资料集中在 `legal/`：

```text
LICENSE
legal/NOTICE.md
legal/COPYING
legal/THIRD_PARTY_NOTICES.md
legal/SOURCE_OFFER.md
legal/third-party/
```

## 仓库策略

不提交 FFmpeg / FFprobe 二进制：

```text
third_party/ffmpeg/macos-arm64/ffmpeg
third_party/ffmpeg/macos-arm64/ffprobe
third_party/ffmpeg/macos-x64/ffmpeg
third_party/ffmpeg/macos-x64/ffprobe
third_party/ffmpeg/macos-universal/ffmpeg
third_party/ffmpeg/macos-universal/ffprobe
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

提交以下说明和元数据：

```text
third_party/ffmpeg/macos-arm64/README.md
third_party/ffmpeg/macos-arm64/ffmpeg-build-info.txt
third_party/ffmpeg/macos-x64/README.md
third_party/ffmpeg/macos-universal/README.md
third_party/ffmpeg/windows-x64/README.md
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

## 构建要求

构建前安装：

```bash
brew install autoconf automake libtool nasm pkg-config
```

构建：

```bash
scripts/build/build_ffmpeg_macos_arch.sh arm64
scripts/build/build_ffmpeg_macos_arch.sh x86_64
scripts/build/build_ffmpeg_macos_universal.sh
```

单架构构建在对应原生 macOS host 上执行。Universal 合并后必须通过：

```text
Architectures: x86_64 arm64
OK: no Homebrew dynamic library dependencies detected
OK: libx264 encoder is available
OK: libmp3lame encoder is available
OK: libwebp encoder is available
OK: libopus encoder is available
OK: libvpx-vp9 encoder is available
OK: libsvtav1 encoder is available
OK: mpeg4 encoder is available
OK: mjpeg encoder is available
OK: prores_ks encoder is available
OK: mp4 / mov / matroska / webm / avi muxers are available
OK: zscale filter is available
OK: tonemap filter is available
```

## 发布要求

公开分发包含 FFmpeg + x264 的 app 时，发布包会包含：

- FrameLean 源码
- FFmpeg、x264、LAME、libwebp、Opus、zimg、libvpx 和 SVT-AV1 的源码获取方式
- FFmpeg 构建脚本和配置参数
- GPLv3 许可证文本
- FFmpeg / x264 / LAME / libwebp / Opus / zimg / libvpx / SVT-AV1 的版权说明
- 用户能够替换或重新构建运行时的说明
- 发布包内许可证目录，包含 `LICENSE`、`legal/NOTICE.md`、`legal/COPYING`、`legal/THIRD_PARTY_NOTICES.md`、`legal/SOURCE_OFFER.md`、`legal/third-party/` 和 FFmpeg 构建元数据

macOS Release app 会把 `legal/`、`LICENSE` 和 `legal/NOTICE.md` 复制到：

```text
FrameLean.app/Contents/Resources/legal/
```

DMG 分发包包含 Universal 2 app bundle，因此许可证、第三方声明和源码获取说明会随应用一起分发。FFmpeg / FFprobe 的两个架构切片必须使用相同依赖版本和许可证配置。

Windows Release 产物会把 `legal/`、`LICENSE` 和 `legal/NOTICE.md` 复制到：

```text
FrameLean.exe directory/legal/
```

## 当前状态

当前项目已经完成本地可分发运行时构建、Release app 内置验证、Windows x64 运行时打包基础支持、GPU 编码能力检测、MP3 / WebP / Opus / VP9 / AV1 / ProRes / AVI 旧格式输出编码器校验、HDR 转 SDR 所需 `zscale` / `tonemap` 滤镜校验、推荐方案 / 自定义目标体积压缩工作流、GPLv3+ 许可证文件、第三方声明、源码分发说明、DMG 打包入口和发布包内法律资料复制。

## 发布检查

- 在每个公开 Release 页面同时提供源码包或清晰源码链接
- 发布前复核 `legal/THIRD_PARTY_NOTICES.md` 中的直接依赖和传递依赖许可证
- 验证另一台 Mac 上的运行和 Gatekeeper 行为
