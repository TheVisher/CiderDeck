# CiderDeck

CiderDeck is a touch-optimized Linux dashboard for the Corsair Xeneon Edge.
It presents configurable pages of tiles for application launching, media and
audio control, weather, system monitoring, updates, screenshots, brightness,
clipboard history, timers, and KDE window management.

The application is built with C++20, Qt 6, and Qt Quick/QML. It is designed
primarily for KDE Plasma on Wayland, although it can run with reduced desktop
integration when optional KDE components are unavailable.

## Status

CiderDeck is under active development. The current package version is 0.1.0,
and configuration formats and platform integrations may still change.

## Requirements

Building CiderDeck requires:

- CMake 3.22 or newer
- A C++20 compiler
- Qt 6.5 or newer with Core, Core5Compat, Gui, QML, Quick, D-Bus, Widgets,
  Quick Controls, Layouts, Dialogs, and Qt5Compat GraphicalEffects

The intended KDE/Wayland experience also uses:

- layer-shell-qt for background-layer placement without focus stealing
- KDE Frameworks 6 WindowSystem for blur effects
- KDE Frameworks 6 StatusNotifierItem for the tray icon
- PulseAudioQt for PipeWire/PulseAudio device and stream control
- ddcutil for external-monitor brightness control
- Extra CMake Modules so CMake can discover KDE Frameworks

On Arch Linux, the build and core runtime dependencies are represented by the
`depends` and `makedepends` arrays in [`pkg/PKGBUILD`](pkg/PKGBUILD).

Optional runtime integrations include:

- `pacman-contrib`, `paru`, and Flatpak for update checks and actions; Konsole
  is used only as a fallback if CiderDeck cannot create its embedded updater terminal
- EasyEffects for audio EQ preset selection
- `nvidia-smi` from `nvidia-utils` for NVIDIA GPU monitoring
- `gtk-launch` from GTK 3 for launching some desktop entries
- MPRIS-compatible media players for media controls
- Network access to `wttr.in` for weather data

The screenshot tile invokes whichever KDE global action is assigned to
`Meta+Shift+S`, matching the system shortcut instead of hardcoding a screenshot
application.

Direct touchscreen input reads Linux evdev devices. The user running CiderDeck
must have permission to open the Xeneon Edge device under `/dev/input`. General
Settings shows the detected device, direct-input status, and a five-point
calibration action. Calibration is previewed before it is saved; Cancel restores
the previous mapping, while Reset requires a second confirmation tap.

## Build

Configure and build a development binary from the repository root:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j"$(nproc)"
```

Build artifacts are written to `build/`, which is ignored by Git.

## Run

Launch the development binary with:

```bash
./build/ciderdeck
```

On first launch, CiderDeck creates a default layout. The normal configuration
files are:

```text
~/.config/ciderdeck/config.json
~/.config/ciderdeck/mixer.json
~/.config/ciderdeck/touch-calibration.json
```

To keep development settings separate from an installed dashboard, use the
preview configuration:

```bash
cmake -S . -B build-next -DCMAKE_BUILD_TYPE=Debug
cmake --build build-next -j"$(nproc)"

CIDERDECK_CONFIG_DIR="$HOME/.config/ciderdeck-next" \
  CIDERDECK_PREVIEW=1 \
  ./build-next/ciderdeck
```

If the installed dashboard is running as a Plasma autostart service, stop it
before launching the preview and restore it afterward:

```bash
systemctl --user stop app-ciderdeck@autostart.service
# Run the preview here.
systemctl --user start app-ciderdeck@autostart.service
```

### Environment variables

| Variable | Purpose |
|---|---|
| `CIDERDECK_CONFIG_DIR` | Overrides the directory containing `config.json`, `mixer.json`, and `touch-calibration.json`. |
| `CIDERDECK_PREVIEW` | Uses the preview application name and display name when set. |
| `CIDERDECK_PREVIEW_PAGE` | Selects the initial zero-based page index for preview captures. |
| `CIDERDECK_KWIN_SCRIPT` | Overrides the path to the KWin bridge JavaScript file. |

## Test and lint

Tests are enabled by default through CTest. After configuring and building:

```bash
ctest --test-dir build --output-on-failure
```

The model tests cover tile type conversion, tile JSON serialization, and grid
collision/free-position logic. They redirect configuration writes to a
temporary directory and do not read or modify the user's CiderDeck settings.

Lint all QML files with:

```bash
qmllint -I src/qml src/qml/*.qml
```

To configure a production build without compiling tests:

```bash
cmake -S . -B build-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF
cmake --build build-release -j"$(nproc)"
```

## Install

Configure with the desired installation prefix, build, and install:

```bash
cmake -S . -B build-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_TESTING=OFF
cmake --build build-release -j"$(nproc)"
sudo cmake --install build-release
```

The install step writes the binary, desktop entry, system-wide autostart entry,
application icon, and KWin bridge script. Installing to `/usr` and
`/etc/xdg/autostart` requires elevated privileges.

Arch Linux users can build the local package with:

```bash
cd pkg
makepkg -si
```

## Architecture

- `src/app/` is the composition root. `CiderDeckApp` constructs services and
  view models, exposes them to QML, loads the interface, and configures the
  dashboard window.
- `src/models/` contains persistent page, tile, monitor, and global settings
  data. `DeckConfig` reads and writes the JSON configuration.
- `src/viewmodels/` contains grid collision/editing logic, toast state, and
  installed-application models.
- `src/services/` integrates with audio, MPRIS, weather, Linux system metrics,
  updates, screenshots, brightness, clipboard, KWin, and evdev touch input.
- `src/qml/` contains the dashboard shell, page/grid components, settings UI,
  overlays, and individual tile implementations.
- `src/resources/` contains the compiled icon resource collection.
- `kwin-scripts/` contains the JavaScript bridge loaded through KWin's D-Bus
  scripting interface.
- `pkg/` contains the Arch Linux packaging recipe.

At startup, C++ services and view models are registered as QML context
properties. QML renders pages from `DeckConfig`, while edit operations use
`EditModeController` and `TileGridModel` to validate placement before saving
changes back to the JSON configuration.

## Documentation

- [`docs/NEXT.md`](docs/NEXT.md) describes the current redesign and isolated
  preview workflow.
- [`docs/DESIGN-SYSTEM.md`](docs/DESIGN-SYSTEM.md) documents visual components,
  icons, colors, and tile conventions.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) records deferred features and known KDE
  integration constraints.

## License

CiderDeck is distributed under the GNU General Public License version 3 or
later. See [`LICENSE`](LICENSE).
