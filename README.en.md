<div align="center">
  <img src="./Pastable/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Pastable Logo" width="96" />
  <h1>Pastable</h1>
  <p><strong>A lightweight and fast clipboard manager for macOS</strong></p>
  <p>Built around an instant floating panel and smarter search to make copy-paste workflows frictionless.</p>
  <p>
    <a href="./README.md">简体中文</a> ·
    <a href="./README.en.md">English</a>
  </p>
  <p>
    <img alt="Platform" src="https://img.shields.io/badge/Platform-macOS-111111?logo=apple" />
    <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?logo=swift" />
    <img alt="Data" src="https://img.shields.io/badge/Data-SwiftData-0A84FF" />
    <a href="https://github.com/QiuZHsGitHub/Pastable/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/QiuZHsGitHub/Pastable?display_name=tag" /></a>
    <img alt="License" src="https://img.shields.io/github/license/QiuZHsGitHub/Pastable" />
  </p>
</div>

<p align="center">
  <img src="./design/theme-cinnabar/preview/figma-panel-dark.png" alt="Pastable Cinnabar Preview" width="100%" />
</p>

## Table of Contents

- [Themes](#themes)
- [Highlights](#highlights)
- [Quick Start](#quick-start)
- [Download](#download)
- [Usage](#usage)
- [Settings](#settings)
- [iCloud Sync](docs/icloud.md)
- [Project Structure](#project-structure)
- [Inspirations](#inspirations)
- [License](#license)

## Figma

- Dark design space: [Pastable / UI 2026](https://www.figma.com/design/4lqk62cQU0WffNMgUXkGez/Paste?node-id=2006-6)
- Light design space: [Pastable / UI 2026 · Light](https://www.figma.com/design/4lqk62cQU0WffNMgUXkGez/Paste?node-id=2011-11)
- Tokens and handoff: [docs/figma.md](docs/figma.md) · [docs/theme.md](docs/theme.md)
- China Trend theme (implemented): [Figma](https://www.figma.com/design/4lqk62cQU0WffNMgUXkGez/Paste?node-id=2026-2) · [Design notes](design/theme-cinnabar/README.md)
- Panel frame: [Dark](https://www.figma.com/design/4lqk62cQU0WffNMgUXkGez/Paste?node-id=2006-15) · [Light](https://www.figma.com/design/4lqk62cQU0WffNMgUXkGez/Paste?node-id=2011-24)

## Themes

Follows the **macOS system Light / Dark appearance** by default. Since 2026-10 the theme is **China Trend · Cinnabar**: opaque layered surfaces, all text uses solid tokens instead of white/black alpha, and cinnabar is reserved for emphasis:

- Dark: panel `#2C2A29 → #141211`, text `#F6F1EA / #ACA49B / #8E867D`, accent `#E0523B`
- Light: panel `#F5F0E9 → #DDD2C4`, cards `#FFFDFB`, text `#1B1816 / #4A443D / #5C554C`, accent `#C8402E`
- Cards: category tint over the card base, Dark 18%/24%, Light 12%/20%
- Category colors: Text `#4E8F7C`, Code `#4A7DB2`, Link `#9A72A8`, Media `#C46F88`, Color `#D9824B`

<p align="center">
  <img src="./design/theme-cinnabar/preview/figma-panel-dark.png" alt="Pastable Cinnabar Dark" width="49%" />
  <img src="./design/theme-cinnabar/preview/figma-panel-light.png" alt="Pastable Cinnabar Light" width="49%" />
</p>

See [docs/theme.md](docs/theme.md) for the full token and Figma mapping, and [design/theme-cinnabar](design/theme-cinnabar/README.md) for the design generator.

## Highlights

- **Bottom floating panel**: instantly opens recent clipboard history
- **Dock layering**: the panel stays above the Dock while open, so cards are never covered and the panel stays flush with the bottom edge
- **Smart search**: supports both exact and fuzzy matching
- **Auto content detection**: text, code, links, images, and files
- **One-click paste**: select a card to restore clipboard and paste immediately
- **History management**: retention window, capacity control, and manual cleanup
- **Optional iCloud sync**: sync clipboard history across Macs signed in with the same Apple ID through a private CloudKit database
- **Custom shortcuts**: configurable global hotkey for panel toggle

<p align="center">
  <img src="./design/theme-cinnabar/preview/figma-panel-dark.png" alt="Pastable Cinnabar panel (2026-10)" width="100%" />
</p>

## Quick Start

### 1) Clone

```bash
git clone https://github.com/QiuZHsGitHub/Pastable.git
cd Pastable
```

### 2) Install dependencies

Follow `./DEPENDENCIES.md` to add Swift Package dependencies in Xcode.

### 3) Run

1. Open `./Pastable.xcodeproj`
2. Select the `Pastable` scheme
3. Choose a macOS target and run

## Download

- Latest release: <https://github.com/QiuZHsGitHub/Pastable/releases/latest>
- Download the `.dmg` package from the release assets

## Usage

- **Toggle panel**: use your configured shortcut (default `Cmd + Shift + V`); the panel never steals keyboard focus
- **Focus search**: `Cmd + Shift + F`
- **Quick paste**: click a card, or select one and press `Enter`
- **Select a card**: `←` / `→` while the search field is empty
- **Number shortcuts**: `Cmd + 1…9` or `Fn + 1…9` to paste the Nth item
- **Delete card**: hover it (or select it) and press `Cmd + Delete`
- **Close panel**: `Esc` or the global shortcut again

## Settings

- Search mode: Exact / Fuzzy (searches titles and full content; all tokens must match)
- Auto paste (requires Accessibility permission; a clear prompt is shown and the app falls back to copy-only)
- Remove formatting
- Sound feedback
- Save types: Text / Image / File (disabled types are no longer captured)
- History limit and retention duration (actually enforced; a one-time prompt offers Clean Up / Keep Everything / Later)
- iCloud sync (off by default; uses a private CloudKit database, see [docs/icloud.md](docs/icloud.md))
- Launch at login, storage usage statistics

> Large TIFF screenshots are converted to PNG in the background, dramatically shrinking the store. Images also get a small pre-rendered thumbnail and display metadata (character/file counts, payload size) at capture time, so cards never decode the original.

## Development & Tests

```bash
swift test    # 52 logic tests using an in-memory store
xcodebuild -project Pastable.xcodeproj -scheme Pastable \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/PastableDerived CODE_SIGNING_ALLOWED=NO build
```

Use `PASTABLE_STORAGE_DIR=/tmp/PastableTest` to redirect the database while debugging.

## Project Structure

```text
Pastable/
├── Core/          # lifecycle, clipboard monitor, search, theme
├── Models/        # history models and content parsing
├── Persistence/   # SwiftData persistence, dedup, retention
├── UI/            # floating panel, cards, settings views
└── Extensions/    # shared extensions and pasteboard types
Tests/             # SwiftPM unit tests
```

## Inspirations

- Raycast
- Alfred
- Pastebot
- Maccy
- Clipy

## License

This project is open-sourced under the [MIT License](./LICENSE).
