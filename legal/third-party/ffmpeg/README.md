# FFmpeg / static libav SDK

FrameLean release packages include FEngine statically linked with a libav SDK
built from FFmpeg 7.1.1 and GPL components including x264 / libx264. They do
not include or launch ffmpeg / ffprobe executable programs.

Upstream source:

- FFmpeg: <https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz>
- FFmpeg project: <https://ffmpeg.org/>

Local build entrypoint:

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

The macOS runtime build metadata is mirrored in ffmpeg-build-info.txt and kept
beside the tracked source and build inputs in `dependencies/ffmpeg/`.
Distributed macOS builds link FEngine against the generated Universal 2 SDK in
`build/dependencies/ffmpeg/macos-universal/`.

Distributed builds must not enable FFmpeg's `--enable-nonfree` option.
