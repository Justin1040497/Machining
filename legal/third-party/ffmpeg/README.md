# FFmpeg / FFprobe

FrameLean release packages can include FFmpeg and FFprobe runtime binaries.
The current documented runtime is FFmpeg 7.1.1 built with GPL components,
including x264 / libx264.

Upstream source:

- FFmpeg: <https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz>
- FFmpeg project: <https://ffmpeg.org/>

Local build entrypoint:

```text
scripts/build/build_ffmpeg_macos_arm64.sh
```

The macOS runtime build metadata is mirrored in ffmpeg-build-info.txt and kept
beside the runtime placeholder in third_party/ffmpeg/macos-arm64/.

Distributed builds must not enable FFmpeg's `--enable-nonfree` option.
