# Source Code and Build Information

FrameLean is distributed under the GNU General Public License, version 3 or
any later version published by the Free Software Foundation.

## Corresponding Source

The corresponding source for FrameLean includes:

- FrameLean application source code.
- Build scripts and packaging metadata in this repository.
- FFmpeg runtime build scripts and metadata in `scripts/build/` and
  `third_party/ffmpeg/`.
- Documentation needed to rebuild or replace the bundled FFmpeg / FFprobe
  runtime.

When a binary build of FrameLean is publicly distributed, the corresponding
source should be made available from the same release location, or from a
clearly linked public source repository, for as long as required by GPLv3.

## FFmpeg Runtime

Current FrameLean builds target FFmpeg 7.1.1 with x264/libx264, LAME/libmp3lame,
libwebp, and Opus/libopus enabled.

The macOS architecture build and Universal 2 merge scripts are:

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

The architecture script is run once on an Apple Silicon host with `arm64` and
once on an Intel host with `x86_64`. The merge script creates the distributed
Universal 2 runtime.

The documented FFmpeg configure flags include:

```text
--enable-gpl
--enable-version3
--enable-libx264
--enable-libmp3lame
--enable-libwebp
--enable-libopus
--enable-videotoolbox
--enable-audiotoolbox
--disable-shared
--enable-static
--disable-sdl2
--disable-debug
--disable-doc
--disable-ffplay
```

`--enable-nonfree` must not be used for distributed builds.

## Upstream Source Locations

- FrameLean source: publish this repository or a source archive for each binary
  release.
- FFmpeg source: <https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz>
- x264 source: <https://code.videolan.org/videolan/x264>
- LAME source: <https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz>
- libwebp source: <https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz>
- Opus source: <https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz>

If a release uses different FFmpeg, x264, LAME, libwebp, or Opus versions,
update this file and the runtime build metadata before distributing that
release.

## User Replacement and Rebuild

FrameLean resolves FFmpeg / FFprobe from bundled runtime locations, known system
locations, PATH, or user-configured custom paths, depending on platform and app
settings. Users should be able to replace or rebuild the FFmpeg / FFprobe
runtime with a GPL-compatible build.

Release packaging includes this legal directory, the root LICENSE file,
legal/NOTICE.md, and the relevant FFmpeg build metadata so recipients receive
the license terms and source availability information with the binary package.
