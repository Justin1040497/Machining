# Third-Party Notices

This file summarizes major third-party components used by FrameLean. It is not
a substitute for each upstream project's own license text. Release packages
should include the upstream license files or clear links to the corresponding
source archives.

## Project License

FrameLean application source code is distributed under:

```text
GNU General Public License v3.0 or later
SPDX-License-Identifier: GPL-3.0-or-later
```

See the root LICENSE file and legal/COPYING in this repository.

## Media Runtime

### FFmpeg / FFprobe

- Upstream: <https://ffmpeg.org/>
- Source for current documented runtime: <https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz>
- Current FrameLean configuration: GPLv3-or-later route, because the runtime is
  built with `--enable-gpl`, `--enable-version3`, `--enable-libx264`,
  `--enable-libmp3lame`, `--enable-libwebp`, and `--enable-libopus`.
- Nonfree configuration: `--enable-nonfree` must not be enabled for distributed
  builds.
- Local build reference: `scripts/build/build_ffmpeg_macos_arm64.sh`

FFmpeg and FFprobe are maintained by the FFmpeg project. FrameLean only invokes
and distributes the runtime binaries when they are included in release packages.

### x264 / libx264

- Upstream: <https://www.videolan.org/developers/x264.html>
- Source: <https://code.videolan.org/videolan/x264>
- Used by FrameLean through the FFmpeg runtime via `--enable-libx264`.

x264 is a GPL-licensed H.264 encoder. Because FrameLean distributes an FFmpeg
runtime with x264 enabled, FrameLean release packages should follow the GPLv3+
source and license delivery path documented in legal/SOURCE_OFFER.md.

### LAME / libmp3lame

- Upstream: <https://lame.sourceforge.io/>
- Source for current documented runtime: <https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz>
- Used by FrameLean through the FFmpeg runtime via `--enable-libmp3lame`.

LAME provides MP3 encoding support for the bundled FFmpeg runtime.

### libwebp

- Upstream: <https://chromium.googlesource.com/webm/libwebp/>
- Source for current documented runtime: <https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz>
- Used by FrameLean through the FFmpeg runtime via `--enable-libwebp`.

libwebp provides WebP image encoding support for the bundled FFmpeg runtime.

### Opus / libopus

- Upstream: <https://opus-codec.org/>
- Source for current documented runtime: <https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz>
- Used by FrameLean through the FFmpeg runtime via `--enable-libopus`.

Opus provides Opus and Ogg Opus audio encoding support for the bundled FFmpeg
runtime.

## Flutter and Dart

FrameLean is built with Flutter and Dart. Flutter, Dart, and many official
Dart packages are distributed under BSD-style licenses. Release packages should
preserve the license notices shipped by the Flutter SDK and Dart packages.

## Direct Dart Package Dependencies

The project currently declares these direct runtime dependencies in
`pubspec.yaml`:

| Package | License observed in local package cache | Role |
| --- | --- | --- |
| `cupertino_icons` | MIT | Cupertino icon font |
| `flutter_riverpod` | MIT | State management |
| `go_router` | BSD-style | Navigation |
| `uuid` | MIT | UUID generation |
| `drift` | MIT | Database abstraction |
| `sqlite3_flutter_libs` | MIT | SQLite runtime libraries |
| `path_provider` | BSD-style | Platform storage paths |
| `path` | BSD-style | Path manipulation |
| `args` | BSD-style | CLI argument parsing |
| `file_selector` | BSD-style | Native file picking |
| `desktop_drop` | Apache-2.0 | Desktop drag and drop |

The project currently declares these direct development dependencies:

| Package | License observed in local package cache | Role |
| --- | --- | --- |
| `flutter_lints` | BSD-style | Lint rules |
| `drift_dev` | MIT | Drift code generation |
| `build_runner` | BSD-style | Dart code generation runner |
| `flutter_launcher_icons` | MIT | App icon generation |
| `dmg` | MIT | macOS DMG packaging helper |

Before each public binary release, regenerate or review the dependency license
inventory from `pubspec.lock` and the package cache, because transitive
dependencies may change when packages are upgraded.

## Assets

Application icons and other assets in this repository are part of FrameLean
unless a more specific license notice appears next to the asset.
