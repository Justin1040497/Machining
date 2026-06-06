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

Current FrameLean builds target FFmpeg 7.1.1 with x264/libx264 enabled.

The macOS arm64 build script is:

```text
scripts/build/build_ffmpeg_macos_arm64.sh
```

The documented FFmpeg configure flags include:

```text
--enable-gpl
--enable-version3
--enable-libx264
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

If a release uses different FFmpeg or x264 versions, update this file and the
runtime build metadata before distributing that release.

## User Replacement and Rebuild

FrameLean resolves FFmpeg / FFprobe from bundled runtime locations, known system
locations, PATH, or user-configured custom paths, depending on platform and app
settings. Users should be able to replace or rebuild the FFmpeg / FFprobe
runtime with a GPL-compatible build.

Release packaging includes this legal directory, the root LICENSE file,
legal/NOTICE.md, and the relevant FFmpeg build metadata so recipients receive
the license terms and source availability information with the binary package.
