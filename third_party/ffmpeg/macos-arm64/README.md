# macOS arm64 FFmpeg Runtime

This directory is the local drop point for the bundled macOS arm64 `ffmpeg` and
`ffprobe` binaries.

The binaries are intentionally ignored by Git:

- `ffmpeg`
- `ffprobe`

Build them with:

```bash
scripts/build_ffmpeg_macos_arm64.sh
```

The macOS Runner target copies these files into:

```text
machining.app/Contents/Resources/ffmpeg/
```

Release builds that include these binaries must follow the GPL FFmpeg + x264
distribution notes in `docs/reference/ffmpeg-license-distribution.md`.
