# CiderDeck Design System

## Icons

### Icon Library: Lucide
All UI control icons in CiderDeck use [Lucide](https://lucide.dev/icons/) — an open-source, MIT-licensed icon set with consistent 24x24 stroke-based SVGs.

**Why Lucide:**
- Cross-platform — bundled as SVG resources, no system icon theme dependency
- Consistent style — uniform stroke width, rounded caps, minimal aesthetic
- Scalable — vector SVGs render crisp at any size
- Themeable — white base stroke, colorized at runtime via `ColorOverlay`

### Usage in QML

Use the shared `LucideIcon` component:

```qml
LucideIcon {
    width: 24; height: 24
    source: "qrc:/icons/lucide/play.svg"
    color: themeManager.textColor
}
```

- `width`/`height`: Set to any pixel size — SVGs scale perfectly
- `source`: Always use `qrc:/icons/lucide/<name>.svg`
- `color`: Tints the icon to match the theme. Use `themeManager.textColor` for standard, `themeManager.accentColor` for active states, `themeManager.secondaryTextColor` for dimmed

### When NOT to Use Lucide

Dynamic app-specific icons should still use the system icon theme via `image://appicon/`:
- **App launcher tiles**: `"image://appicon/" + desktopFile` — shows the app's own icon
- **Weather icons**: `"image://appicon/" + weatherService.icon` — weather condition icons
- **Media player identity**: `"image://appicon/" + mprisManager.playerIcon` — Spotify/Firefox/etc. logo as placeholder when album art is unavailable

Rule of thumb: If the icon represents a **UI action** (play, pause, delete, settings), use Lucide. If it represents an **external app or content**, use the system icon theme.

### Available Icons

Icons are stored in `src/resources/icons/lucide/` and registered in `src/resources/icons.qrc`.

| Icon | File | Used For |
|------|------|----------|
| play | `play.svg` | Media play, timer start |
| pause | `pause.svg` | Media pause, timer pause |
| skip-back | `skip-back.svg` | Previous track |
| skip-forward | `skip-forward.svg` | Next track |
| rewind | `rewind.svg` | Seek backward 10s (browser) |
| fast-forward | `fast-forward.svg` | Seek forward 10s (browser) |
| shuffle | `shuffle.svg` | Spotify shuffle toggle |
| repeat | `repeat.svg` | Spotify repeat (playlist) |
| repeat-1 | `repeat-1.svg` | Spotify repeat (track) |
| volume-2 | `volume-2.svg` | Volume unmuted |
| volume-1 | `volume-1.svg` | Volume low |
| volume-x | `volume-x.svg` | Volume muted |
| sun | `sun.svg` | Brightness |
| moon | `moon.svg` | Dark mode |
| monitor | `monitor.svg` | Show desktop |
| layout-grid | `layout-grid.svg` | Overview |
| camera | `camera.svg` | Screenshot |
| terminal | `terminal.svg` | Command button |
| x | `x.svg` | Close, delete, kill process |
| rotate-ccw | `rotate-ccw.svg` | Timer reset |
| settings | `settings.svg` | Settings |
| plus | `plus.svg` | Add |
| trash-2 | `trash-2.svg` | Delete |
| edit-2 | `edit-2.svg` | Edit |
| check | `check.svg` | Confirm |
| search | `search.svg` | Search |
| clock | `clock.svg` | Clock |
| timer | `timer.svg` | Timer |
| eye | `eye.svg` | Show/visible |
| eye-off | `eye-off.svg` | Hide/hidden |
| chevron-left | `chevron-left.svg` | Navigate left |
| chevron-right | `chevron-right.svg` | Navigate right |
| grip-vertical | `grip-vertical.svg` | Drag handle |
| maximize-2 | `maximize-2.svg` | Maximize/expand |
| minimize-2 | `minimize-2.svg` | Minimize/collapse |
| square | `square.svg` | Stop |

#### Weather Icons

Weather icons are mapped from [wttr.in](https://wttr.in) weather codes in `WeatherService.cpp`. The `icon` property returns a Lucide icon name, and QML constructs the path as `"qrc:/icons/lucide/" + icon + ".svg"`.

| Icon | File | Weather Condition |
|------|------|-------------------|
| sun | `sun.svg` | Clear (code 113) |
| cloud-sun | `cloud-sun.svg` | Partly cloudy (code 116), default fallback |
| cloud | `cloud.svg` | Cloudy/overcast (119, 122) |
| cloud-fog | `cloud-fog.svg` | Mist/fog (143, 248, 260) |
| cloud-lightning | `cloud-lightning.svg` | Thunderstorm (200, 386-395) |
| cloud-snow | `cloud-snow.svg` | Snow (179, 227, 230, 323-338, 368, 371) |
| cloud-rain | `cloud-rain.svg` | Rain/drizzle/showers (176+, catch-all) |

Additional weather-related icons available for future use:

| Icon | File | Potential Use |
|------|------|---------------|
| cloud-drizzle | `cloud-drizzle.svg` | Light drizzle |
| cloud-moon | `cloud-moon.svg` | Partly cloudy (night) |
| cloud-sun-rain | `cloud-sun-rain.svg` | Sun shower |
| cloud-moon-rain | `cloud-moon-rain.svg` | Night rain |
| snowflake | `snowflake.svg` | Freezing/ice |
| wind | `wind.svg` | Wind speed indicator |
| thermometer | `thermometer.svg` | Temperature display |
| droplets | `droplets.svg` | Humidity indicator |
| umbrella | `umbrella.svg` | Rain advisory |
| sunrise | `sunrise.svg` | Sunrise time |
| sunset | `sunset.svg` | Sunset time |

### Adding New Icons

1. Download from https://unpkg.com/lucide-static/icons/<name>.svg
2. Replace `stroke="currentColor"` with `stroke="#ffffff"` in the SVG
3. Place in `src/resources/icons/lucide/`
4. Add to `src/resources/icons.qrc`
5. Use via `"qrc:/icons/lucide/<name>.svg"` in QML

## Sliders

### Standard Slider Component

All slider-based tiles (Volume, Brightness, and any future sliders) follow an identical layout and sizing pattern.

### Layout

**Vertical (height > width):**
```
┌──────────────┐
│   [icon]     │  ← Icon/button at top (32×32 * contentScale hit area)
│              │
│    ║║║║      │  ← Track (centered horizontally)
│    ║║║║      │
│   [○]        │  ← Knob (centered on track)
│    ║║║║      │
│              │
│    72%       │  ← Percent text at bottom
└──────────────┘
```

**Horizontal (width >= height):**
```
┌──────────────────────────────┐
│  [icon]  ═══════○══════ 72%  │
└──────────────────────────────┘
```

### Structure

Both layouts use the same wrapper pattern:
```qml
Item {
    anchors.fill: parent
    anchors.margins: 8         // Standard 8px padding from tile edge

    Column/Row {
        anchors.fill: parent
        spacing: 4 (vertical) / 6 (horizontal)

        // 1. Icon (toggleable via showIcon/showMuteBtn)
        // 2. Track (fills remaining space)
        // 3. Percent text (toggleable via showPercent)
    }
}
```

### Track Sizing

| Property | Formula | Default (scale=1) |
|----------|---------|-------------------|
| Track thickness | `8 * sliderScale` | 8px |
| Track radius | `trackThick / 2` | 4px (fully rounded) |

`sliderScale` comes from `settings.sliderThickness` (default 1.0, range 0.5–5.0).

### Knob Sizing

The knob base size is `trackThick + 12 * knobScale` — always a fixed margin larger than the track. The **shape** then determines the final dimensions from this base.

`knobScale` comes from `settings.knobSize` (default 1.0, range 0.5–3.0).

### Knob Shape

Each shape produces visually distinct knob geometry from the same `knobBase`:

| Shape | Cross-axis | Along-axis | Radius | Visual |
|-------|-----------|------------|--------|--------|
| `"pill"` (default) | `knobBase` | `max(knobBase * 0.55, 8)` | `along / 2` | Wide capsule with fully rounded ends |
| `"circle"` | `knobBase` | `knobBase` | `knobBase / 2` | Perfect circle |
| `"square"` | `knobBase * 0.85` | `knobBase * 0.85` | `3` | Rounded square (3px corners) |

### Orientation Swap

For **vertical** sliders: knob width = `thumbCross`, knob height = `thumbAlong`.
For **horizontal** sliders: knob width = `thumbAlong`, knob height = `thumbCross`.

### Example Sizes at Various Settings

Default knobScale=1.0, pill shape:

| Track Scale | Track | knobBase | Pill | Circle | Square |
|-------------|-------|----------|------|--------|--------|
| 0.5× | 4px | 16 | 16×9 | 16×16 | 14×14 |
| 1× (default) | 8px | 20 | 20×11 | 20×20 | 17×17 |
| 2× | 16px | 28 | 28×15 | 28×28 | 24×24 |
| 3× | 24px | 36 | 36×20 | 36×36 | 31×31 |
| 5× | 40px | 52 | 52×29 | 52×52 | 44×44 |

### Slider Colors

Each slider element has an independently configurable color via per-tile settings. Empty string `""` means "use tile default."

| Element | Setting Key | Brightness Default | Volume Default |
|---------|------------|-------------------|----------------|
| Icon | `iconColor` | `#FFD54F` (yellow) | `themeManager.textColor` |
| Bar fill | `barColor` | `#FFD54F` (yellow) | `themeManager.accentColor` |
| Knob | `knobColor` | `white` | `white` |
| Percent text | `percentColor` | `themeManager.textColor` | `themeManager.textColor` |

The track background always uses `themeManager.borderColor`. The knob border always uses `themeManager.borderColor`.

**Muted state (volume only):** When muted, bar fill and percent text fall back to `themeManager.secondaryTextColor` regardless of custom color settings. This provides a clear visual cue that audio is muted.

**Color picker UI:** Settings panel shows 10 preset swatches (Default, White, Blue, Yellow, Red, Green, Orange, Purple, Cyan, Pink) plus a hex text input for custom colors.

### Knob Position Clamping

The knob is clamped to the track bounds rather than adding margins to the track. This keeps the track at full length regardless of knob size:

```qml
// Vertical: clamp Y so knob stays within track
y: Math.max(0, Math.min(parent.height - height,
    parent.height * (1 - value) - height / 2))

// Horizontal: clamp X so knob stays within track
x: Math.max(0, Math.min(parent.width - width,
    parent.width * value - width / 2))
```

At the extremes (0% and 100%), the knob sits flush with the track edge. In the middle range, it's centered on the value position. This avoids the track shrinking away from the icon/percent when knob size increases.

### Settings Keys

These settings apply to any slider tile:

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `sliderThickness` | real | 1.0 | 0.5–5.0 | Track thickness multiplier |
| `knobSize` | real | 1.0 | 0.5–3.0 | Knob margin multiplier |
| `knobShape` | string | `"pill"` | pill/circle/square | Knob corner style |
| `showPercent` | bool | true | — | Show percentage text |
| `iconColor` | string | `""` (default) | hex or `""` | Icon tint color |
| `barColor` | string | `""` (default) | hex or `""` | Fill bar color |
| `knobColor` | string | `""` (default) | hex or `""` | Knob fill color |
| `percentColor` | string | `""` (default) | hex or `""` | Percent text color |

---

## Colors

Colors are provided by `ThemeManager` and should be used via property bindings:

| Role | Property | Usage |
|------|----------|-------|
| Primary text | `themeManager.textColor` | Main text, active icons |
| Secondary text | `themeManager.secondaryTextColor` | Subtitles, dimmed icons |
| Accent | `themeManager.accentColor` | Highlights, active toggles, progress bars |
| Background | `themeManager.backgroundColor` | Card backgrounds |
| Border | `themeManager.borderColor` | Card borders, separators |
| Overlay | `themeManager.overlayColor` | Hover states, button backgrounds |
| Success | `themeManager.successColor` | Command success flash |
| Error | `themeManager.errorColor` | Command error, delete buttons |

---

## Settings Panel

### Layout

The settings panel is a slide-out overlay (520px wide) anchored to the right edge of the screen. It opens in two modes:
- **General Settings** — global appearance, grid, display, and config options
- **Tile Settings** — per-tile configuration (label, opacity, type-specific controls)

### Draggable

The panel header (top 48px) is a drag handle. Users can drag the panel left/right to reveal content underneath. Drag uses `mapToItem(parent)` for stable parent-space coordinates. The panel animates back with `Easing.OutCubic` when released.

### Text Scaling

All settings UI text scales independently from tile content via `deckConfig.settingsTextScale`. This is exposed as a ComboBox dropdown in General Settings with preset sizes:

| Option | Scale | Label Base Size |
|--------|-------|-----------------|
| Small | 0.8× | 11px |
| Medium | 0.9× | 13px |
| Default | 1.0× | 14px |
| Large | 1.2× | 17px |
| X-Large | 1.4× | 20px |

Text sizes are applied via a `ts` alias property in each settings component:
```qml
readonly property real ts: deckConfig.settingsTextScale
// Then: font.pixelSize: 15 * ts
```

The `SettingsRow` component (label + content) also scales its label column width: `Layout.preferredWidth: 140 * deckConfig.settingsTextScale`.

### Color Pickers

Slider color pickers use a `Flow` layout (not `RowLayout`) so swatches wrap to multiple lines when text scale increases. Each color row is a `ColumnLayout` with label above and `Flow` of swatches below, giving full panel width for the swatch grid.

10 preset swatches: Default, White, Blue, Yellow, Red, Green, Orange, Purple, Cyan, Pink — plus a hex text input for custom colors.

---

## Clipboard Tile

### Architecture

```
QClipboard + Klipper D-Bus → ClipboardService (QAbstractListModel)
                                    ↓
                             ClipboardImageProvider (image://clipboard/<entryId>)
                                    ↓
                             ClipboardHistoryTile.qml (ListView)
```

### Data Sources

The clipboard tile uses two complementary data sources to work around Wayland's focus-gated clipboard access:

1. **Klipper D-Bus** (`org.kde.klipper /klipper`) — Listens for `clipboardHistoryUpdated` signal, then calls `getClipboardContents()` for text. Works **without Wayland focus**, so text entries appear immediately.

2. **QClipboard** (`QApplication::clipboard()`) — Reads full MIME data including images. Only works **with focus**. Triggered on `dataChanged` signal and on `applicationStateChanged → ApplicationActive`.

Text copies show up instantly via Klipper. Image copies appear when the user interacts with CiderDeck (Wayland protocol limitation — image data transfer requires focus).

### Image Thumbnails

Clipboard images are stored as `QImage` in the `Entry` struct, scaled to max 600×600px. A `ClipboardImageProvider` (registered as `image://clipboard/<entryId>`) serves thumbnails to QML. Each entry has a unique `entryId` (auto-incrementing `quint64`) so image URLs remain stable as items shift in the list.

### Click Behavior

Clicking a clipboard entry:
1. Copies the entry to the system clipboard (text or image)
2. **Moves it to the top** of the list (removes from old position, re-inserts at index 0 with updated timestamp)
3. Blocks both `QClipboard::dataChanged` (`ignoreNextChange_`) and Klipper D-Bus (`lastManualCopyText_`) from re-adding it

The top entry is always the current clipboard content. No highlight/selection state needed.

### Deduplication

| Source | Dedup Method |
|--------|-------------|
| Text entries | Compare `entry.text` against `history_[0].text` |
| Image entries | Compare `QImage` pixel data (`operator==`) against `history_[0].image` |
| Manual copy (click) | `ignoreNextChange_` + `lastManualCopyText_` block both signal paths |

### Layout

```
┌─────────────────────────────┐
│        Clipboard            │  ← Header (centered, scaled, toggleable)
├─────────────────────────────┤
│ 02:30:12                    │  ← Timestamp (optional)
│ ┌─────────────────────────┐ │
│ │   [image thumbnail]     │ │  ← Image (configurable height)
│ └─────────────────────────┘ │
│ 02:28:44                    │
│ Some copied text that wraps │  ← Text (wraps, max 3 lines, elided)
│ to multiple lines here...   │
│                             │
│            🗑               │  ← Clear button (trash icon, bottom center)
└─────────────────────────────┘
```

- **Header**: Centered, scales with `contentScale`, toggleable via `showHeader` setting
- **Text entries**: `wrapMode: Text.Wrap`, `maximumLineCount: 3`, `elide: Text.ElideRight`
- **Image entries**: Thumbnail at configurable height, `fillMode: Image.PreserveAspectFit`
- **Clear button**: Trash icon at bottom center, turns red on hover, calls `clipboardService.clear()`
- **Empty state**: "No clipboard history" centered text when list is empty
- **Scrollable**: ListView with optional scrollbar (toggle via `showScrollbar` setting)

### Settings Keys

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `showHeader` | bool | true | — | Show "Clipboard" header |
| `showTimestamps` | bool | true | — | Show entry timestamps |
| `showScrollbar` | bool | true | — | Show scroll indicator |
| `thumbnailHeight` | int | 80 | 30–200 | Base thumbnail height (× contentScale) |
| `maxEntries` | int | 20 | 5–50 | Maximum history entries |
