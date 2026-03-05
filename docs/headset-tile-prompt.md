# Headset Tile Implementation Prompt

Copy everything below the line into the CiderDeck chat.

---

## Task

Add a **HeadsetTile** that controls a SteelSeries Arctis Nova Pro Wireless headset via the `headsetcontrol` CLI tool. The tile should display:

1. **Battery indicator** — polled periodically, shows percentage + icon
2. **Connected indicator** — dot or icon showing if headset is online
3. **Sidetone slider** — adjustable 0-128, controls how much mic audio feeds back into ears
4. **Light toggle** — on/off button for headset LEDs

## headsetcontrol CLI Reference

The tool is at `/usr/bin/headsetcontrol`. All commands support `-o JSON` for structured output.

**Read battery + connection status (JSON):**
```
headsetcontrol -b -o JSON
```
Returns:
```json
{
  "devices": [{
    "status": "success",
    "battery": { "status": "BATTERY_AVAILABLE", "level": 25 }
  }]
}
```
Battery status values: `"BATTERY_AVAILABLE"`, `"BATTERY_CHARGING"`, `"BATTERY_UNAVAILABLE"` (headset off/disconnected).

**Check connected:**
```
headsetcontrol --connected
```
Returns `true` or `false` (plain text, exit code 0=connected, non-zero=disconnected).

**Set sidetone (0-128):**
```
headsetcontrol -s 64
```
Write-only — no way to read current value. The service should track it internally after setting.

**Set lights on/off:**
```
headsetcontrol -l 1    # on
headsetcontrol -l 0    # off
```
Write-only — no way to read current state. Track internally.

## Architecture — What to Create

### 1. `src/services/HeadsetService.h` and `HeadsetService.cpp`

Follow the **BrightnessService** pattern. Key design:

```
class HeadsetService : public QObject {
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int batteryLevel READ batteryLevel NOTIFY batteryChanged)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY batteryChanged)
    Q_PROPERTY(int sidetone READ sidetone NOTIFY sidetoneChanged)
    Q_PROPERTY(bool lightsOn READ lightsOn NOTIFY lightsChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
};
```

**Behavior:**
- On construction, check if `headsetcontrol` exists via `QStandardPaths::findExecutable`. Set `available_` accordingly.
- Start a **QTimer** that polls battery + connected status every 30 seconds (configurable). Use `QProcess` async (like BrightnessService's ddcutil pattern) — never block the UI thread.
- Parse JSON output from `headsetcontrol -b -o JSON` to extract battery level and status.
- Derive `connected` from battery status: if status is `"BATTERY_UNAVAILABLE"` or the process fails, headset is disconnected.
- `setSidetone(int level)`: Run `headsetcontrol -s <level>` async. Clamp to 0-128. Use a **busy guard** like BrightnessService's `ddcBusy_` to prevent overlapping calls. Throttle during slider drag (the QML tile handles this with a Timer, just like BrightnessTile).
- `setLights(bool on)`: Run `headsetcontrol -l <0|1>` async. Track state internally.
- Sidetone and lights are write-only at the hardware level — initialize both to sensible defaults (sidetone=0, lights=true) and track after set.

### 2. `src/qml/HeadsetTile.qml`

This tile has a **compound layout** — not just a single slider. It combines multiple controls in one tile. Use adaptive layout based on `sizeClass`:

**Layout (vertical, medium+ size):**
```
┌─────────────────────────┐
│  🎧  Headset     ● 25%  │  ← Icon + label + connected dot + battery
│                          │
│  ├── Sidetone ──────○──  │  ← Horizontal slider (like BrightnessTile horizontal mode)
│                          │
│       💡 Lights  [ON]    │  ← Light toggle button
└─────────────────────────┘
```

**Tiny/small size:** Show only battery % + connected dot (most essential info). Hide sidetone slider and light toggle — not enough room.

**Key implementation details:**
- Inherit from `Card` (not CardButton — this isn't a single-click tile)
- Battery icon should change based on level: use different icons for charging vs low vs medium vs full
- Connected dot: small circle, green when connected, dim/gray when disconnected
- Sidetone slider: Follow the **BrightnessTile horizontal slider** pattern exactly, including the throttle Timer to prevent spamming headsetcontrol during drag. Range is 0-128 (not 0-100), so map accordingly.
- Light toggle: A small clickable rectangle or icon button. Toggle icon between lit/unlit states.
- When disconnected, dim/disable all controls and show "Disconnected" text

**Tile settings (in TileSettings.qml):**
- `pollInterval`: Battery poll interval in seconds (default 30, range 10-300)
- `showSidetone`: Show/hide sidetone slider (default true)
- `showLights`: Show/hide light toggle (default true)
- Standard slider color pickers (barColor, knobColor) for the sidetone slider

### 3. Lucide Icons Needed

Download these SVGs from https://lucide.dev and add to `src/resources/icons/lucide/`. Remember to replace `stroke="currentColor"` with `stroke="#ffffff"` in each SVG (project convention).

- `headphones.svg` — main tile icon
- `battery.svg` — battery indicator (generic)
- `battery-low.svg` — low battery
- `battery-medium.svg` — medium battery
- `battery-full.svg` — full battery
- `battery-charging.svg` — charging state
- `lightbulb.svg` — lights on
- `lightbulb-off.svg` — lights off

Add all of them to `src/resources/icons.qrc` in the `<qresource prefix="/icons/lucide">` section.

### 4. Registration (all the plumbing)

**`src/models/TileType.h`:**
- Add `Headset` to the enum (after the last entry, before the closing brace)
- Add `case TileType::Headset: return QStringLiteral("headset");` to `tileTypeToString()`
- Add `if (str == "headset") return TileType::Headset;` to `tileTypeFromString()`

**`src/qml/TileLoader.qml`:**
- Add case: `case "headset": return headsetComponent`
- Add component at bottom: `Component { id: headsetComponent; HeadsetTile {} }`

**`src/qml/TileSettings.qml`:**
- Add a `ColumnLayout` block with `visible: tileSettings.tileType === "headset"` containing:
  - Poll interval setting (SettingsRow with a number input, 10-300 seconds)
  - Show sidetone toggle (SettingsRow with a switch)
  - Show lights toggle (SettingsRow with a switch)
  - Slider color pickers (follow the BrightnessTile color picker pattern)

**`src/app/CiderDeckApp.h`:**
- Forward declare: `class HeadsetService;`
- Add member: `HeadsetService *headsetService_ = nullptr;`

**`src/app/CiderDeckApp.cpp`:**
- Include: `#include "HeadsetService.h"`
- Instantiate in `run()` alongside other services: `headsetService_ = new HeadsetService(this);`
- Register context property: `ctx->setContextProperty("headsetService", headsetService_);`
- Optionally wire a toast for low battery: connect `batteryChanged` signal and show toast when level drops below 15%

**`CMakeLists.txt`:**
- Add `src/services/HeadsetService.h` and `src/services/HeadsetService.cpp` to the `add_executable` source list

**`src/qml/qml.qrc`:**
- Add `<file>HeadsetTile.qml</file>` to the qresource list

## Reference Files

For exact patterns to follow, read these existing files in the project:

| Pattern | File |
|---|---|
| Service with async QProcess + busy guard | `src/services/BrightnessService.h` and `.cpp` |
| Slider tile with throttled drag | `src/qml/BrightnessTile.qml` |
| Slider tile with mute button | `src/qml/VolumeTile.qml` |
| Button tile with flash feedback | `src/qml/CommandButtonTile.qml` |
| Tile type registration | `src/models/TileType.h` |
| Tile loading switch | `src/qml/TileLoader.qml` |
| Tile settings panel | `src/qml/TileSettings.qml` (search for "brightness" section as template) |
| Service wiring | `src/app/CiderDeckApp.cpp` `run()` method |
| Icon convention | `docs/DESIGN-SYSTEM.md` § Icons |
| Slider design specs | `docs/DESIGN-SYSTEM.md` § Sliders |
