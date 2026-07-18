# FFmpeg Native Adapter

`framelean-ffmpeg` 使用低层 sys bindings 在 Engine 进程内调用 libavformat、libavcodec 和 libavutil。所有 unsafe、裸指针和 AVFormatContext 所有权留在该 crate。

当前开发构建通过 `rusty_ffmpeg` 的系统链接模式使用本机 headers/libraries。macOS 本机已验证媒体打开、多 Stream 映射以及 Demuxer/Muxer/Decoder/Encoder 枚举。枚举只证明 `NativeDiscovered`；本次不执行 `avcodec_open2` 或硬件设备 qualification，因此不会报告 `NativeInitializable`。

Stream duration 使用完整 AVRational 并通过 `av_rescale_q` 转为微秒。视频位深优先使用 `bits_per_raw_sample`，缺失时由 Pixel Format Descriptor 的组件深度推导。图片动图判断只把 `nb_frames > 1` 作为帧数证据；独立 InputContext 的最多 256 packet/16 MiB 有界扫描不会把 packet 数写成 frame 数。无法确认时返回静态 Image、Partial 和 `MEDIA_ANIMATION_STATE_NOT_PROBED`。

Backend Catalog 按 BackendId 规范化后使用 BLAKE3 计算 revision。Decoder/Encoder 记录 avcodec 版本，Demuxer/Muxer 记录 avformat 版本；能力或 execution readiness 变化都会改变 revision。

强制启用 crate 的 FFmpeg 8.1 feature 与当前 Homebrew headers API 集不兼容，因此具体 FFmpeg feature、预生成 bindings、三平台 bundled library、ABI、许可证和发布 manifest 仍属于 native qualification，尚未锁定为发布事实。

永久禁止调用 ffmpeg/ffprobe executable、shell、PATH、CLI 参数或解析 CLI 输出。
