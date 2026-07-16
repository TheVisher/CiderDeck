# CiderDeck Next

CiderDeck Next is an isolated visual redesign that keeps the existing native
service layer and modular tile grid. The installed CiderDeck binary and its
configuration remain unchanged while the preview is evaluated.

## Design Scope

- Unified charcoal control surfaces with restrained borders and shadows
- Touch-oriented volume and brightness rails
- Configurable media artwork fades, layouts, progress, and control alignment
- Refined current-conditions weather layout
- Normalized launcher icons, labels, and running indicators
- Smooth horizontal page transitions with full-screen and edge swipe navigation
- Configurable CPU, GPU, memory, storage, network, and overview monitoring tiles
- Compact process monitoring with KWin-backed unresponsive-window indicators
- Existing clock, edit mode, app picker, settings, and tile movement retained
- Existing per-tile opacity and slider customization retained

Advanced audio routing and virtual PipeWire channels are intentionally outside
this pass.

The preview layout is intentionally not tracked because it contains local
monitor identifiers, installed application IDs, and location settings. Back up
or transfer the files in the preview configuration directory to preserve the
exact dashboard arrangement.

## Isolated Preview

The preview reads configuration from:

```text
~/.config/ciderdeck-next/config.json
~/.config/ciderdeck-next/mixer.json
```

Build and run it with:

```bash
cmake -S . -B build-next -DCMAKE_BUILD_TYPE=Debug
cmake --build build-next -j$(nproc)
systemctl --user stop app-ciderdeck@autostart.service
CIDERDECK_CONFIG_DIR="$HOME/.config/ciderdeck-next" \
  CIDERDECK_PREVIEW=1 \
  ./build-next/ciderdeck
```

Restore the installed dashboard with:

```bash
systemctl --user start app-ciderdeck@autostart.service
```

## Validation

The preview has been built, checked with `qmllint`, launched on `DP-3`, and
visually inspected from a native `2560x720` screen capture. The existing
project currently has no CTest test targets.
