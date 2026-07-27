# bundled static libav 许可与分发

## 当前选择

FrameLean 采用 `GPL-3.0-or-later` 作为项目整体开源许可证。FEngine 在进程内静态链接由 FFmpeg 7.1.1 构建得到的 libav SDK，并启用 x264 / libx264、LAME / libmp3lame、libwebp、Opus / libopus、zimg / libzimg、libvpx 和 SVT-AV1。因此包含该静态链接引擎的发布包需要按 GPLv3+ 路线处理。

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

构建脚本使用 `--disable-programs`，SDK 不生成也不分发 FFmpeg CLI 程序；
Desktop runtime 只包含静态链接该 SDK 的 FEngine：

```text
build/dependencies/ffmpeg/<platform>/include/
build/dependencies/ffmpeg/<platform>/lib/
desktop release/FEngine executable
```

提交以下构建脚本、说明和元数据：

```text
build/dependencies/ffmpeg/macos-arm64/README.md
build/dependencies/ffmpeg/macos-arm64/ffmpeg-build-info.txt
build/dependencies/ffmpeg/macos-x64/README.md
build/dependencies/ffmpeg/macos-universal/README.md
build/dependencies/ffmpeg/windows-x64/README.md
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
scripts/build/build_ffmpeg_windows_x64.sh
```

## 构建要求

### macOS

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

单架构构建在对应原生 macOS host 上执行。

### Windows

安装 MSYS2 及 MinGW-w64 工具链：

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make \
  mingw-w64-x86_64-pkg-config mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-nasm mingw-w64-x86_64-libtool \
  mingw-w64-x86_64-binutils autoconf automake git curl tar
```

构建（在 MSYS2 MINGW64 shell 中执行）：

```bash
bash scripts/build/build_ffmpeg_windows_x64.sh
```

构建完成后，FEngine 需要在对应 SDK 上完成静态链接；发布脚本还会拒绝最终 FEngine 的动态 libav（及 Windows GNU runtime DLL）依赖。能力验证的具体命令、库列表和输出以构建脚本为准，不能把 `ffmpeg -encoders` 或 `ffprobe` 作为应用运行时检查。

历史构建日志可能包含如下 FFmpeg configure 能力断言：

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

公开分发包含静态链接 libav + x264 的 FEngine 时，发布包会包含：

- FrameLean 源码
- FFmpeg、x264、LAME、libwebp、Opus、zimg、libvpx 和 SVT-AV1 的源码获取方式
- FFmpeg 构建脚本和配置参数
- GPLv3 许可证文本
- FFmpeg / x264 / LAME / libwebp / Opus / zimg / libvpx / SVT-AV1 的版权说明
- 用户能够重新构建 bundled static libav SDK 与 FEngine 的说明
- 发布包内许可证目录，包含 `LICENSE`、`legal/NOTICE.md`、`legal/COPYING`、`legal/THIRD_PARTY_NOTICES.md`、`legal/SOURCE_OFFER.md`、`legal/third-party/` 和 SDK 构建元数据

macOS Release app 会把 `legal/`、`LICENSE` 和 `legal/NOTICE.md` 复制到：

```text
FrameLean.app/Contents/Resources/legal/
```

DMG 分发包包含 Universal 2 app bundle，因此许可证、第三方声明和源码获取说明会随应用一起分发。两套 static libav 架构切片必须使用相同依赖版本和许可证配置。app bundle 只携带静态链接后的 FEngine，不携带 `ffmpeg` / `ffprobe` executable。

Windows Release 产物会把 `legal/`、`LICENSE` 和 `legal/NOTICE.md` 复制到：

```text
FrameLean.exe directory/legal/
```

## 当前状态

当前项目已经完成 static libav SDK 构建、静态链接 FEngine 的发布验证、Windows x64 打包基础支持、GPLv3+ 许可证文件、第三方声明、源码分发说明、DMG 打包入口和发布包内法律资料复制。实际可执行的媒体链以 FLL Runtime 当前实现为准；尚未接入的完整转码链必须 fail closed，不能以旧 CLI 能力表宣称为已支持。

## 发布检查

- 在每个公开 Release 页面同时提供源码包或清晰源码链接
- 发布前复核 `legal/THIRD_PARTY_NOTICES.md` 中的直接依赖和传递依赖许可证
- 验证另一台 Mac 上的运行和 Gatekeeper 行为
