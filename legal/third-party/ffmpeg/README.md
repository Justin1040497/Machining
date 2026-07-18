# FFmpeg / FFprobe

FrameLean release packages can include FFmpeg and FFprobe runtime binaries.
The current documented runtime is FFmpeg 7.1.1 built with GPL components,
including x264 / libx264.

Upstream source:

- FFmpeg: <https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz>
- FFmpeg project: <https://ffmpeg.org/>

Local build entrypoint:

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

The macOS runtime build metadata is mirrored in ffmpeg-build-info.txt and kept
beside the runtime placeholders in third_party/ffmpeg/. Distributed macOS
builds use the Universal 2 runtime in third_party/ffmpeg/macos-universal/.

Distributed builds must not enable FFmpeg's `--enable-nonfree` option.
