# macOS arm64 FFmpeg Runtime

This directory is the build output for the macOS arm64 `ffmpeg` and `ffprobe`
slice.

The binaries are intentionally ignored by Git:

- `ffmpeg`
- `ffprobe`

Build them with:

```bash
scripts/build/build_ffmpeg_macos_arm64.sh
```

The release app does not copy this directory directly. Merge it with the Intel
slice first:

```bash
scripts/build/build_ffmpeg_macos_universal.sh
```

The macOS Runner copies only `../macos-universal/` into the app.
