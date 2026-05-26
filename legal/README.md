# Legal Materials

This directory is the canonical home for FrameLean's release legal materials.
The repository root keeps LICENSE and NOTICE as standard discovery entry
points, and release packages include those two files together with this
directory.

## Package Layout

Binary release packages carry these materials:

- LICENSE
- NOTICE
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
project license text and the root NOTICE file as the short distribution notice.
