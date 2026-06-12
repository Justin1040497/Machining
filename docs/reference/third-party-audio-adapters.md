# 第三方音频适配参考

本文记录 FrameLean 专有音频导入适配相关的第三方参考、运行时边界和许可证处理要求。

## NCM

FrameLean 主程序不打包 `ncmdump` 二进制，也不把第三方 NCM 项目源代码直接 vendored 进仓库。当前实现位于：

```text
lib/infrastructure/services/proprietary_audio/ncm/
```

实现形态：

- 使用 Dart 读取 NCM 容器、还原音频密钥和生成 key box。
- 使用 `pointycastle` 提供 AES-ECB/PKCS7 基础能力。
- 解包后的文件根据文件头识别为 MP3 或 FLAC，再进入现有 FFprobe / FFmpeg 链路。

行为参考：

- `taurusxin/ncmdump`: MIT，作为 NCM 容器行为参考和人工对照来源。

发布前要求：

- 在 release checklist 中锁定参考仓库的 commit 或 release。
- 确认 FrameLean 只参考行为，没有复制不兼容代码。
- 将 `pointycastle` 许可证纳入第三方声明材料。

## QMC / MGG / MFLAC

MGG / MFLAC 等 QMC 变体不在主程序里原生实现。FrameLean 优先约定外部适配器运行时：

```text
framelean-qmc-adapter --input <source> --output-dir <temporary-dir> --format <qmcMgg|qmcMflac>
```

同时兼容直接放置上游 `qmc-decrypt` 可执行文件：

```text
qmc-decrypt <source> <temporary-dir>
```

运行时发现路径：

```text
<executable>/audio_adapters/qmc/framelean-qmc-adapter
<executable>/audio_adapters/qmc/qmc-decrypt
<app Resources>/audio_adapters/qmc/framelean-qmc-adapter
<app Resources>/audio_adapters/qmc/qmc-decrypt
third_party/audio_adapters/qmc/<platform>/framelean-qmc-adapter
third_party/audio_adapters/qmc/<platform>/qmc-decrypt
tools/audio_adapters/qmc/framelean-qmc-adapter
tools/audio_adapters/qmc/qmc-decrypt
```

适配器要求：

- 只读取本地输入文件。
- 只写入 FrameLean 分配的临时输出目录。
- 不联网、不登录、不下载、不调用音乐平台 API。
- 成功后输出 MP3、FLAC、OGG、M4A、AAC 或 WAV 等标准音频文件。
- FrameLean wrapper 适配器支持 `--version`，用于运行时可用性检测。
- 直接使用上游 `qmc-decrypt` 时改用 `--help` 探测，因为当前锁定版本不提供 `--version`。

候选参考：

- `qmc-decrypt`: MIT 或 Apache-2.0；可直接作为 QMC 外部适配器候选。其 README 明确 `mgg1` / `mflac0` 需要手动提供 `ekey`，FrameLean 当前没有 ekey 输入 UI，所以这些变体不能被过度承诺。

发布前要求：

- 锁定实际采用的开源仓库、commit、构建脚本和许可证文本。
- 将适配器源码、构建产物和许可证放在 `third_party/audio_adapters/qmc/` 下。
- macOS / Windows 打包脚本复制 adapter 时同步复制许可证和 notice。

当前构建脚本：

```text
scripts/build/build_qmc_decrypt_macos_arm64.sh
scripts/build/build_qmc_decrypt_windows.ps1
```

这两个脚本锁定 `bczhc/qmc-decrypt` commit `12d758a6a08635b4ab85b6dca05025fdbcc26520`，构建产物分别放入 `third_party/audio_adapters/qmc/macos-arm64/` 和 `third_party/audio_adapters/qmc/windows-x64/`。macOS / Windows 发布脚本会在对应产物存在时自动复制到应用包。

Windows GitHub Actions 会在发布构建中调用
`scripts/build/build_qmc_decrypt_windows.ps1`，因此 Windows ZIP 和 Inno Setup
安装器必须包含 `qmc-decrypt.exe`、构建信息和上游许可证。Windows 发布和
安装器校验同时接受 `framelean-qmc-adapter.exe` 与 `qmc-decrypt.exe`，避免
构建阶段和打包阶段使用不同的适配器文件名契约。
