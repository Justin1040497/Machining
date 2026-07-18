# Legal Materials

This directory contains third-party and release-compliance materials. The
repository root `LICENSE` is the only canonical FrameLean main license file.
The short distribution notice lives in `legal/NOTICE.md`, and release packages
include the root license together with this directory.

## Package Layout

Binary release packages carry these materials:

- LICENSE
- legal/NOTICE.md
- legal/COPYING
- legal/THIRD_PARTY_NOTICES.md
- legal/SOURCE_OFFER.md
- legal/third-party/

macOS release builds copy this directory into:

```text
FrameLean.app/Contents/Resources/legal/
```

DMG packages contain the app bundle, so the legal materials are distributed
inside the DMG with the application.

Windows release builds copy this directory into:

```text
FrameLean.exe directory/legal/
```

## Maintenance

Update this directory when changing bundled runtimes, direct dependencies,
license policy, or release packaging. Keep the root LICENSE file as the full
project license text and legal/NOTICE.md as the short distribution notice.
