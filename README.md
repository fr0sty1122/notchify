# Notchify

A native macOS (Sonoma 14+) SwiftUI app that turns the MacBook notch into an
interactive Dynamic Island.

## Install

```bash
./Scripts/install.sh
```

Builds a universal (Apple Silicon + Intel) app, installs it to
`/Applications/Notchify.app`, and launches it.

## Develop

```bash
./Scripts/dev.sh           # build once and (re)launch from ./build
./Scripts/dev.sh --watch   # rebuild + relaunch on every source change
```

## Package for distribution

```bash
./Scripts/package.sh       # produces dist/Notchify-<version>.dmg
```

Creates a styled, HiDPI drag-to-Applications disk image with a branded icon.

## Features

- Invisible hover trigger over the real notch; the island stays open while the
  pointer is inside it.
- Compact now-playing pill in the notch with a live equalizer.
- Apple Music and Spotify now-playing controls.
- Calendar with today highlighted in the accent color.
- Camera mirror to quickly check your appearance.
- Temporary file shelf (drag files in and back out).
- Quick notes with titles, saved across launches.
- Clipboard history.
- Preferences window (opens when you launch the app from Applications) with
  accent color, behavior, tab, and launch-at-login controls.

## Permissions

- Apple Events: Apple Music / Spotify controls.
- Camera: the mirror.

## Architecture

- `App/` — `AppDelegate` wires the services, overlay panel, hover monitor,
  hotkey, and preferences window. `NotchifyApp` is the SwiftUI entry point.
- `Overlay/` — the borderless floating `NSPanel` that hosts the island.
- `Models/` — value types (`MediaTrack`, `NoteItem`, etc.) and `SettingsStore`.
- `Services/` — system integrations (media, camera, clipboard, notes,
  shelf, hotkey, login item, notch metrics, hover/window positioning).
- `ViewModels/` — `IslandViewModel`, the single source of UI state.
- `Views/` — the SwiftUI island, feature tabs, and preferences.

## License

Notchify is free and open source under the [MIT License](LICENSE).
