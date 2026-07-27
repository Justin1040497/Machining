# FFmpeg Native Adapter

`framelean-ffmpeg` 使用低层 sys bindings 在 Engine 进程内调用 libavformat、libavcodec 和 libavutil。所有 unsafe、裸指针和 AVFormatContext 所有权留在该 crate。

开发、测试和发布构建都通过 `scripts/build/with_bundled_ffmpeg.sh` 使用 `build/dependencies/ffmpeg/<platform>/` 下的 bundled static libav SDK。构建不回退到系统或 Homebrew FFmpeg。macOS arm64 已验证最终 FEngine 不依赖 `libav*.dylib`；macOS Universal 2 与 Windows x64 在各自原生 CI runner 上构建并检查发布产物。

媒体打开、多 Stream 映射以及 Demuxer/Muxer/Decoder/Encoder 枚举只证明 `NativeDiscovered`。已实现的 software video execution path 在实际执行中调用 `avcodec_open2`，仅将资格化的软件 decoder、`libx264` encoder 和 `ffmpeg.processor.swscale.pixel-format-conversion` 标记为 Engine execution ready；硬件设备和其他 discovered backend 不会被标记为 ready。

Stream duration 使用完整 AVRational 并通过 `av_rescale_q` 转为微秒。视频位深优先使用 `bits_per_raw_sample`，缺失时由 Pixel Format Descriptor 的组件深度推导。图片动图判断只把 `nb_frames > 1` 作为帧数证据；独立 InputContext 的最多 256 packet/16 MiB 有界扫描不会把 packet 数写成 frame 数。无法确认时返回静态 Image、Partial 和 `MEDIA_ANIMATION_STATE_NOT_PROBED`。

Backend Catalog 按 BackendId 规范化后使用 BLAKE3 计算 revision。Decoder/Encoder 记录 avcodec 版本，Demuxer/Muxer 记录 avformat 版本；能力或 execution readiness 变化都会改变 revision。

当前 SDK 由仓库脚本固定 FFmpeg feature、静态库、headers、许可证和 manifest；具体平台构建输入以 `dependencies/ffmpeg/` 与对应构建脚本为事实源，可重建二进制只进入被忽略的 `build/dependencies/`。

当前实际 execution scope 是 packet stream-copy/remux，以及一个严格限定的 video path：单一视频流、无音频、软件 decoder、可选 swscale 像素格式转换、`libx264` 和 MP4 输出。音频、多流、HDR tone mapping、任意 Plugin Processor 的 native-frame 桥接、其他 container/codec 组合和 hardware encoding 均 fail closed。

永久禁止调用 ffmpeg/ffprobe executable、shell、PATH、CLI 参数或解析 CLI 输出。
