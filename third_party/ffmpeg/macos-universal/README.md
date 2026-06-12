# macOS Universal 2 FFmpeg Runtime

FrameLean's macOS release consumes this directory. It must contain Universal 2
FFmpeg and FFprobe binaries with both `x86_64` and `arm64` slices.

Build the architecture slices on native hosts, then merge them:

```bash
scripts/build/build_ffmpeg_macos_universal.sh
```

The merge script validates architectures, required codecs, and dynamic
dependencies before the runtime can be packaged.
