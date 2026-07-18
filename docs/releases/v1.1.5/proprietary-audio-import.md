# 专有音频输入适配

## 所属版本

`v1.1.5`

## 当前事实

FrameLean 支持部分本地专有音频输入适配。`.ncm` 使用本地 Dart 实现还原为临时标准音频；`.mgg`、`.mflac`、`.qmcflac` 等 QMC 变体通过外部适配器或直接放置的 `qmc-decrypt` 运行时处理，再交给 FFprobe / FFmpeg 走标准音频链路。

## 设计方式

- 专有音频是输入格式，不加入 `MediaOutputFormat` 输出列表。
- `ProprietaryAudioFormatResolver` 按扩展名识别 NCM / QMC 变体。
- `NativeNcmAudioDecoder` 处理 NCM 容器、密钥和临时输出。
- `ProprietaryAudioDecoderDispatcher` 按格式分派到原生 NCM 或外部适配器。
- `BundledProprietaryAudioAdapterRegistry` 发现 `framelean-qmc-adapter` 或 `qmc-decrypt`。
- 直接使用上游 `qmc-decrypt` 时用 `--help` 探测可用性，不要求 `--version`。

## 为什么这样设计

NCM 可以在本地用 Dart 实现，避免随包分发额外 CLI。QMC 变体更多，公开工具覆盖不一致，部分样本需要额外信息，因此保留外部适配器边界，避免把不稳定格式深度耦合进主任务模型。

## 设计收益

- 标准音频处理链路不需要知道源文件是否来自专有输入。
- NCM 不依赖外部 `ncmdump`。
- QMC 能力可以随适配器可用性演进，不阻断普通媒体发布。
- UI 文案可以保持克制，表达为“本地专有音频导入适配”。

## 当前边界

- 不做在线转换、登录、下载或平台 API 调用。
- 不承诺所有 QMC 变体都可处理。
- 需要额外密钥的 QMC 变体当前不提供输入 UI。

## 关联

- `docs/reference/third-party-audio-adapters.md`
- `docs/lessons.md#直接使用上游 qmc-decrypt 时不要假设有 --version`
