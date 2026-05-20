# FFmpeg 许可与分发

## 当前选择

Machining v1.3.0+1 采用 `GPL-3.0-or-later` 作为项目整体开源许可证。项目内置 FFmpeg 7.1.1，并启用 x264 / libx264。因此包含该运行时的发布包需要按 GPLv3+ 路线处理。

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

仓库已经补齐基础许可资料。根目录保留标准发现入口，完整发布法律资料集中在 `legal/`：

```text
LICENSE
NOTICE
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

公开分发包含 FFmpeg + x264 的 app 时，发布包会包含：

- Machining 源码
- FFmpeg 和 x264 的源码获取方式
- FFmpeg 构建脚本和配置参数
- GPLv3 许可证文本
- FFmpeg / x264 的版权说明
- 用户能够替换或重新构建运行时的说明
- 发布包内许可证目录，包含 `LICENSE`、`NOTICE`、`legal/COPYING`、`legal/THIRD_PARTY_NOTICES.md`、`legal/SOURCE_OFFER.md`、`legal/third-party/` 和 FFmpeg 构建元数据

macOS Release app 会把 `legal/`、`LICENSE` 和 `NOTICE` 复制到：

```text
Machining.app/Contents/Resources/legal/
```

DMG 分发包包含该 app bundle，因此许可证、第三方声明和源码获取说明会随应用一起分发。

Windows Release 产物会把 `legal/`、`LICENSE` 和 `NOTICE` 复制到：

```text
Machining.exe directory/legal/
```

## v1.3 状态

当前项目已经完成本地可分发运行时构建、Release app 内置验证、Windows x64 运行时打包基础支持、GPU 编码能力检测、智能压缩工作流、GPLv3+ 许可证文件、第三方声明、源码分发说明、DMG 打包入口和发布包内法律资料复制。

## 发布检查

- 在每个公开 Release 页面同时提供源码包或清晰源码链接
- 发布前复核 `legal/THIRD_PARTY_NOTICES.md` 中的直接依赖和传递依赖许可证
- 验证另一台 Mac 上的运行和 Gatekeeper 行为
