---
name: framelean-media-pipeline
description: "Reference FrameLean FLL core processing stages, Node boundaries, Processor and Pipeline data flow, plugin suitability, ownership, and future FFmpeg adapter boundaries. Use when classifying Source, Packet, Frame, Task, Analyzer, codec, filter, encryption, AI, or plugin behavior without treating reserved NodeKind variants as implemented features."
---

# FLL Media Processing Pipeline

把本 Skill 作为领域参考，由阶段 Skill 按需加载；不要替代分析、计划、实现或验证。先读取 `fll/README.md`、`fll/CONTEXT.md` 和 `fll/Cargo.toml`，再核对相关 crate source、tests 与 `fll/docs/`，不要只依赖本 Skill 的摘要。

## 目标链路与当前事实

```text
Source -> Demuxer -> Packet Processor -> Decoder
       -> Video / Audio Processor -> Encoder -> Muxer -> Sink
```

当前媒体执行 Pipeline 只实现 `PacketProcessor`、`VideoProcessor` 和 `AudioProcessor`。`MediaAnalyzer` 已作为独立分析边界实现，`framelean-ffmpeg` 可在进程内探测媒体并报告 Native Backend Catalog；这不代表 Demuxer、Decoder、Encoder、Muxer 或 Sink 已接入执行 Pipeline。其余 `NodeKind` 仍只是预留边界。不要创建 `FakeFFmpeg`、`FakeDecoder` 或 `FakeEncoder`。

## 边界

- Analyzer / Scanner：识别或分析媒体，不修改数据；由 `framelean-analysis` 定义契约，当前 `framelean-ffmpeg` 提供实现，不属于逐帧 Pipeline Stage。
- Processor：处理 Packet、`VideoFrame` 或 `AudioFrame`；一个 Processor 只属于一个 Stage，输入输出与 Stage 一致。
- Pipeline：组织执行、阶段校验和错误短路；不知道 Processor 来自内置还是 Plugin。
- Plugin：注册 `ProcessorFactory`；当前是进程内静态注册，不等同于 DLL、dylib 或 so。
- Runtime：按 `ProcessorId` 查询 Factory，创建 Processor、注入 Pipeline，并管理 Task 和结果。
- Decision：只使用媒体、静态环境、Backend Catalog 与兼容规则求完整链；动态 ResourceSample 只影响 Recommendation、Warning 或调度保护。

## 能力归属

- 整个文件加密：Source / Source Adapter。
- Demux 后音频 Packet 加密：Packet Processor。
- 解码后音频采样处理：Audio Processor。
- 逐帧缩放、裁剪、调色：Video Processor / Filter。
- 场景检测、整段分析、自动剪辑：Task 级分析或更高层能力，不强塞逐帧接口。

标准容器、解码、编码和基础媒体能力属于 FLL 核心处理基础设施；特殊格式、加密、AI、平台规则和可替换算法适合 Processor Factory 扩展。不是所有能力都插件化，FFmpeg 本身不是普通业务插件。

## FFmpeg 与所有权

FFmpeg 当前通过 `framelean-ffmpeg` 的低层 bindings 在进程内链接 bundled static libav SDK，用于媒体探测、Native Backend 事实和受支持的 packet stream-copy/remux。构建必须显式使用 `build/dependencies/ffmpeg/<platform>/`，不得回退到系统或 Homebrew FFmpeg；Desktop package 只携带静态链接后的 FEngine，不携带 ffmpeg/ffprobe CLI。Demux、Decode、Filter、Encode、Mux 的完整执行 Pipeline 仍未全部接入。禁止改回 `Command::new("ffmpeg")`、`ffmpeg.exe`、ffprobe 或等价进程调用。

`MediaBuffer`、`MediaPacket`、`VideoFrame`、`AudioFrame`、`ProcessInput`、`ProcessOutput` 优先 move，不为方便随意 Clone。把 FFI `unsafe` 限制在 `framelean-ffmpeg`，不向上泄漏裸 `AVFrame`、`AVPacket` 或 `AVFormatContext` 指针。
