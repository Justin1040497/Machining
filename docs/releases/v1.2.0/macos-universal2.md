# macOS Universal 2

## 版本事实

FrameLean 的 macOS 发布目标从 Apple Silicon arm64 扩展为 Universal 2：

```text
x86_64 + arm64
```

用户继续下载单一 `FrameLean-v<version>.dmg`。Windows 发布范围保持 x64，不增加 Windows x86。

对应长期决策见 `docs/decisions/260612-macos-universal2-distribution.md`。

## 构建边界

- Flutter macOS Release app 必须包含 x86_64 和 arm64。
- FFmpeg、FFprobe 和随包 QMC 适配器必须分别在原生架构 host 上构建，再使用 `lipo` 合并。
- CI 上传架构 slice 时使用 tar.gz 封装，避免 GitHub Actions artifact zip 丢失 macOS 可执行位；下载后先解包再合并。
- Xcode Build Phase 只从 `macos-universal` 目录复制运行时。
- DMG 构建先生成 app，再扫描包内全部 Mach-O 文件，验证通过后才能进入签名、公证和 DMG 生成。
- QMC 是可选能力；没有 Universal QMC 时可以不随包发布，但不能回退携带纯 arm64 适配器。

## 发布验证

- 本机 Flutter Release app 主体的 Runner、Flutter、App 和插件 Mach-O 文件已通过 Universal 2 扫描。
- Apple Silicon Mac 和 Intel Mac 使用同一 DMG 完成启动、导入、分析和媒体处理。
- 两种架构分别验证 VideoToolbox 能力探测和软件编码回退。
- `otool -L` 不出现 Homebrew 动态库路径。
- `hdiutil verify`、代码签名和公证检查通过。
