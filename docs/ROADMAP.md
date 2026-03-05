# CiderDeck Roadmap

Items to revisit and implement in future sessions.

---

## Overview Tile

### Native KDE Overview compatibility
The native KDE Overview effect (`Meta+W`) is a full-compositor takeover that hides all layer-shell surfaces, including CiderDeck on the Xeneon Edge. Changing the layer-shell level to `LayerOverlay` did not help — the effect covers all outputs regardless of layer.

**Current workaround**: A custom KWin-script-based tiler that saves window positions, arranges them in a grid on the largest non-Xeneon monitor, and restores on second tap.

**To investigate**:
- Whether future KWin/Plasma releases add per-output exclusion for Overview
- Whether a KWin effect plugin could intercept Overview and skip a specific output
- Any compositor-level hooks that could keep a layer-shell surface visible during Overview

### Overview mode toggle (custom vs native)
Add a setting to the Overview tile that lets the user choose between:
1. **Custom overview** (default) — the KWin-script tiler that keeps CiderDeck visible
2. **Native KDE Overview** — triggers `Meta+W` via `kglobalaccel invokeShortcut "Overview"`, which hides CiderDeck but provides the full KDE experience (search, virtual desktops, etc.)

This should be a per-tile setting in the tile's `settings` map (e.g., `"overviewMode": "custom"` or `"overviewMode": "native"`).

---

## Per-Tile Internal Layout Editor

Allow users to move and resize individual components *within* a tile (icons, text, controls, etc.). Each tile would have its own mini grid or freeform positioning system, similar to how tiles themselves are positioned on the dashboard grid.

**Use cases**:
- Reposition the album art, track info, and transport controls within a media player tile
- Move icon vs label positioning within an app launcher tile
- Custom arrangements for any tile type

**Feasibility**: Yes — each tile's child items could be wrapped in a `Repeater` + positioning system driven by per-tile layout data in the config JSON. Edit mode would need a "nested edit" concept (tap a tile in edit mode to enter its internal layout editor).

**Complexity**: High — requires a sub-grid system, per-component drag/resize, config schema extensions, and UI to distinguish between tile-level and component-level editing. Defer until core features are stable.

---

## Media Player

### Spotify like button
Spotify on Linux does not expose a like/save method via D-Bus or MPRIS. If a future Spotify update adds this, wire it into the media tile for Spotify players.

### YouTube/browser interaction buttons
MPRIS only covers playback control (play, pause, seek, next, previous). Content interaction (like, dislike, subscribe, comment) is not exposed via D-Bus by browsers. No known workaround short of browser extension integration.

---

## Audio Mixer

### Per-group EQ via PipeWire virtual sinks
Currently EQ is global — EasyEffects applies one EQ curve to the entire PipeWire output sink (labeled "Output EQ" in the mixer overlay). Per-group EQ would allow each mixer group (Gaming, Media, Comms, etc.) to have its own EQ preset.

**Architecture**:
- Create a PipeWire virtual sink per group using `pw-loopback` or the `filter-chain` module
- Attach a parametric EQ filter-chain to each virtual sink
- Route each group's app streams to their respective virtual sink instead of the default sink
- Virtual sinks output to the real hardware sink

**What it requires**:
- C++ work in AudioMixerService to manage virtual sink lifecycle (create/destroy with groups)
- Filter-chain config management (JSON/Lua) for per-group EQ curves
- Stream rerouting logic (move app streams to virtual sinks instead of default)
- Per-group EQ UI in the mixer overlay (preset picker or parametric controls per column)
- Cleanup: remove virtual sinks when groups are deleted

**Considerations**:
- EasyEffects would still apply globally on top of per-group EQ unless bypassed
- Additional PipeWire resource usage (one filter-chain per group)
- Audio routing debugging becomes more complex
- PipeWire's `filter-chain` module supports parametric EQ natively, so no external dependencies needed
