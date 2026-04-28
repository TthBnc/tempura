# Tempura

Tempura is a native macOS menu bar utility that shows one representative hardware temperature in Celsius or Fahrenheit.

![Tempura menu bar panel](Assets/readme-screenshot.png)

## Download

Download the latest release:

[Tempura 0.5.1](https://github.com/TthBnc/tempura/releases/tag/v0.5.1)

Install from the DMG:

1. Download `Tempura.dmg` from the release page.
2. Open the DMG.
3. Drag `Tempura.app` onto the `Applications` shortcut.
4. Remove the macOS quarantine flag (see below), then launch Tempura from Applications or Spotlight.

### First-launch on macOS

Tempura is ad-hoc signed while I wait on my Apple Developer ID. Once that's set up, releases will be properly signed and notarized and this step will go away. Until then, macOS Gatekeeper will block the first launch with:

> "Tempura" can't be opened because Apple cannot check it for malicious software.

To allow it, run this once after dragging the app to Applications:

```sh
xattr -cr /Applications/Tempura.app
```

Then open Tempura normally. macOS will remember the choice — you only need to do this once per install.

Alternatively, you can right-click Tempura.app in Applications, choose Open, and confirm the warning dialog. Some macOS versions (notably Sequoia and later) no longer offer this
fallback, in which case use the xattr command above.

## Compatibility

Tempura requires macOS 13 Ventura or newer on an Apple Silicon Mac.

## What It Does

- Shows live temperature, memory, and swap metrics in the macOS menu bar.
- Opens a compact panel with the last 60 seconds of local thermal history.
- Colors readings by temperature range.
- Supports Celsius and Fahrenheit display units.
- Lets you choose which menu bar metrics appear and how memory/swap labels are formatted.
- Shows memory usage, swap overflow, and thermal throttle risk in the panel.
- Uses native Liquid Glass surfaces on macOS 26 and a compatible glass fallback on macOS 13-25.
- Can open automatically when you log in.
- Shows version details and checks for updates from a separate settings window only when requested.
- Provides a `Quit Tempura` button in the panel.
- Prevents duplicate app instances.
- Stays local-only while monitoring: no background network calls, telemetry, fan control, or SMC writes. Manual update checks contact GitHub Releases only when you click `Check for Updates`.

## Build From Source

Run the sensor probe first:

```sh
swift run tempura-probe
```

Build the menu bar app bundle:

```sh
./Scripts/build_app.sh
```

The bundle is written to:

```text
.build/app/Tempura.app
```

The app icon is generated from `Assets/AppIcon.svg` into a macOS `.icns` file during the app build.

Build a local drag-install DMG:

```sh
./Scripts/build_dmg.sh
```

The DMG is written to:

```text
dist/Tempura.dmg
```

Open it, then drag `Tempura.app` onto the `Applications` shortcut.

## Development Run

For quick iteration, the executable can run directly:

```sh
swift run Tempura
```

The packaged app is preferred for daily use because `Packaging/Info.plist` sets `LSUIElement` so the app does not appear in the Dock or app switcher.

## Notes

- Reads local SMC temperature values through IOKit.
- Displays the hottest valid CPU/GPU/SoC-adjacent reading when available.
- Falls back to the hottest valid known or scanned temperature reading.
- Polls every 5 seconds.
- Shows `--°C` when no valid sensor is available.

## License

Tempura is released under the MIT License. It is provided as-is, without warranty or liability. See `LICENSE`.

Tempura adapts read-only SMC access patterns and temperature sensor key mappings from Stats. See `THIRD_PARTY_NOTICES.md`.
