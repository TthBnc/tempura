# Tempura

Tempura is a native macOS menu bar utility that shows one representative hardware temperature in Celsius.

The MVP follows the PRD in `docs/thermal-menubar-mvp-prd.md`: no window, no popover, no telemetry, no fan control, and no SMC writes.

## Build

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

## Scope

- Reads local SMC temperature values through IOKit.
- Displays the hottest valid CPU/GPU/SoC-adjacent reading when available.
- Falls back to the hottest valid known or scanned temperature reading.
- Polls every 5 seconds.
- Shows `--°C` when no valid sensor is available.
- Colors the menu bar text orange at `>= 70°C` and red at `>= 85°C`.
- Provides only a right-click or Control-click `Quit` menu.
- Ignores duplicate launches while Tempura is already running.
