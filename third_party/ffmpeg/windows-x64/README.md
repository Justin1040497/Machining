# Windows x64 FFmpeg Runtime

This directory is the local drop point for the bundled Windows x64 `ffmpeg.exe`
and `ffprobe.exe` binaries.

The binaries are intentionally ignored by Git:

- `ffmpeg.exe`
- `ffprobe.exe`

Before building on Windows, place the binaries here:

```text
third_party/ffmpeg/windows-x64/ffmpeg.exe
third_party/ffmpeg/windows-x64/ffprobe.exe
```

The Windows CMake install step copies these files into:

```text
machining.exe directory/ffmpeg/
```

At runtime the app resolves:

```text
<app exe directory>/ffmpeg/ffmpeg.exe
<app exe directory>/ffmpeg/ffprobe.exe
```

If these files are missing, the Windows build fails so the release output does
not accidentally omit the bundled runtime.
