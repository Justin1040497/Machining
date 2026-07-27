# Source Code and Build Information

FrameLean is distributed under the GNU General Public License, version 3 or
any later version published by the Free Software Foundation.

## Corresponding Source

The corresponding source for FrameLean includes:

- FrameLean application source code.
- Build scripts and packaging metadata in this repository.
- Static libav SDK build scripts and metadata in `scripts/build/` and
  `dependencies/ffmpeg/`; generated local runtimes are placed under the
  ignored `build/dependencies/ffmpeg/` directory.
- Documentation needed to rebuild the bundled static libav SDK and the FEngine
  binary linked against it.

When a binary build of FrameLean is publicly distributed, the corresponding
source should be made available from the same release location, or from a
clearly linked public source repository, for as long as required by GPLv3.

## Static libav Runtime

Current FrameLean builds target FFmpeg 7.1.1 with x264/libx264, LAME/libmp3lame,
libwebp, Opus/libopus, zimg/libzimg, libvpx, and SVT-AV1 enabled.

The macOS architecture build and Universal 2 merge scripts are:

```text
scripts/build/build_ffmpeg_macos_arch.sh
scripts/build/build_ffmpeg_macos_universal.sh
```

The Windows x64 build script is:

```text
scripts/build/build_ffmpeg_windows_x64.sh
```

The script is run once on a Windows x64 host with MSYS2/MinGW-w64.

The documented FFmpeg configure flags include:

```text
# Common flags (macOS and Windows)
--enable-gpl
--enable-version3
--enable-libx264
--enable-libmp3lame
--enable-libwebp
--enable-libopus
--enable-libzimg
--enable-libvpx
--enable-libsvtav1
--disable-shared
--enable-static
--disable-sdl2
--disable-debug
--disable-doc
--disable-ffplay
# macOS only
--enable-videotoolbox
--enable-audiotoolbox
# Windows only
--enable-d3d11va
--enable-dxva2
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
- zimg source: <https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz>
- libvpx source: <https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.2.tar.gz>
- SVT-AV1 source: <https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v2.3.0/SVT-AV1-v2.3.0.tar.gz>

If a release uses different FFmpeg, x264, LAME, libwebp, Opus, zimg, libvpx, or SVT-AV1 versions,
update this file and the runtime build metadata before distributing that
release.

## User Replacement and Rebuild

FrameLean does not resolve or execute ffmpeg / ffprobe programs from bundled
locations, system locations, PATH, or app settings. Standard media processing
runs inside FEngine through FLL linked to the bundled static libav SDK. Users
can rebuild that SDK with a GPL-compatible configuration and then rebuild
FEngine through the documented project scripts.

Release packaging includes this legal directory, the root LICENSE file,
legal/NOTICE.md, and the relevant FFmpeg build metadata so recipients receive
the license terms and source availability information with the binary package.
