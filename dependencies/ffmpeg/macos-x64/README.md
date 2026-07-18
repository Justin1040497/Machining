# macOS x86_64 FFmpeg Runtime

This directory is the build output for the Intel macOS FFmpeg and FFprobe
slice. Generate it on a native x86_64 macOS host with:

```bash
scripts/build/build_ffmpeg_macos_arch.sh x86_64
```

The executable files are ignored by Git. The Universal 2 release runtime is
created by merging this directory with `../macos-arm64/`.
