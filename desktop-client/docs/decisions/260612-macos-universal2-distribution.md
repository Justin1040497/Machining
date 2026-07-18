# macOS 采用单一 Universal 2 发布包

## 决策

- macOS 同时支持 Intel x86_64 和 Apple Silicon arm64。
- macOS 只发布一个 Universal 2 DMG，不按 CPU 架构拆分下载入口。
- app、FFmpeg、FFprobe 和随包原生适配器都必须包含 x86_64 与 arm64。
- Windows 继续只支持 x64，不增加 Windows x86 构建和安装器。

## 原因

- 单一 DMG 能保持下载、更新和用户支持路径一致。
- 只把 Flutter app 编译为 Universal 不足以支持 Intel Mac；全部随包 Mach-O
  依赖必须满足同一架构契约。
- Windows x86 会扩大依赖、测试和发布成本，但当前没有明确产品需求。

## 约束

- 两个架构的 FFmpeg 和 QMC 切片分别在对应原生 macOS host 上构建，再通过
  `lipo` 合并。
- DMG 生成前扫描完整 app bundle；任一 Mach-O 缺少 x86_64 或 arm64 都阻止发布。
- 同一个 DMG 必须分别在 Intel Mac 和 Apple Silicon Mac 上完成发布验收。

## 关联事实

- `docs/releases/desktop-client/v1.2.0/macos-universal2.md`
- `docs/develop/technology-stack.md`
- `docs/develop/test-plan.md`
