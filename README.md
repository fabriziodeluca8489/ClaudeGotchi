# ClaudeGotchi 🐣

[🇮🇹 Italiano](README.it.md) · 🇬🇧 English

An animated companion that lives on your desktop, always on top of other windows, showing
**what Claude Code is doing**: idle, working (reading, writing, using the terminal),
waiting for your permission, done. When a task finishes it jumps, flashes and plays a sound,
so you notice even while working in another app.

Hover over the character to see session stats: context tokens, output tokens and tools run.

- 3 characters: **Developer**, **Robot**, **Star Puccioso**
- 9 animations (one per activity), with configurable sprites and FPS
- Dashboard with live preview, sizes, backgrounds and choice of info to show
- Two versions: **native macOS** (Swift) and **Electron** for **Windows** and macOS

## How it works

```
Claude Code ──hooks──▶ ClaudeGotchi ──▶ animated character
```

Four Claude Code hooks (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`) report the state
to the app. Token counts are read from the session transcript. Everything stays on your
computer: the Electron version receives hooks via `curl` on `127.0.0.1:47823`, the native macOS
one through a JSON file at `~/.claude/tamagotchi-state.json`.

## Installation

### Windows (and macOS) — Electron version

Requirements: [Node.js](https://nodejs.org) 18+ and `curl` (bundled with Windows 10/11 and macOS).

```bash
cd windows
npm install
npm run build:win     # Windows -> windows/dist/ClaudeGotchi.exe (portable)
npm run build:mac     # macOS   -> windows/dist/*.zip
npm start             # or run directly without building
```

Launch the app: the Dashboard opens on first run. In the *Claude Code* section click **Installa**
(Install) — it adds 4 hooks to your `~/.claude/settings.json`, with a backup in `settings.json.bak` —
then **restart any Claude Code sessions already open**. If Windows SmartScreen warns you,
choose "More info" → "Run anyway" (the app is unsigned).

### macOS — native version (Swift)

Requirements: macOS 13+, Xcode/Swift 6, `jq` (`brew install jq`).

```bash
./build_app.sh                      # creates ClaudeGotchi.app
cp -r ClaudeGotchi.app /Applications/
open /Applications/ClaudeGotchi.app
```

Then right-click the character → **Installa hooks Claude Code** (or
`ClaudeGotchi --install-hooks`) and restart Claude Code. To remove them: **Rimuovi hooks**.

> The app interface is currently in Italian.

## Usage

- **Drag** the character anywhere. **Right-click** for the menu (skin, size, Dashboard,
  hooks, donate, quit).
- **Dashboard**: animation and FPS per activity, skin, size, background, info shown
  (caption, tool, tokens, tool calls), idle time before sleeping.
- **Activities**: idle, sleeping, reading (Read/Grep/Glob), writing (Edit/Write),
  terminal (Bash), working (other tools), waiting for permission, done, error.

## Adding animations

Animations are horizontal transparent strips in `Sources/ClaudeGotchi/Resources/`, named
`<name>_<rows>x<columns>.png` (e.g. `idle_1x8.png`). The app reads the grid from the file name
and lists them all in the dashboard. Default names per activity: `idle`, `sleep`, `reading`,
`writing_code`, `terminal`, `working`, `waiting_permission`, `done`, `error`.
Each character has a prefix: Developer none, Robot `robot_`, Star `star_`.

A raw strip (irregular or overlapping frames) can be imported with:

```bash
python3 tools/import_sprite.py ~/Downloads/error.png error 8   # file, name, frame count
./build_app.sh
```

The script cuts between characters, removes fragments of neighbouring frames, fills the eye
whites and bottom-aligns the frames. For characters without eye whites (robot) add `--no-eyes`.
For the Electron version also copy the PNGs to `windows/assets/` and, for a new skin, register it
in `windows/shared.js` (`SKINS`).

## Structure

```
Sources/ClaudeGotchi/   # native macOS app (SwiftUI/AppKit)
windows/                # Electron app (Windows/macOS): main.js, pet.html, dashboard.html, assets/
hooks/                  # bash hook scripts (native version) + test_hooks.sh
tools/import_sprite.py  # imports a generated sprite strip
```

## ☕ Donate

ClaudeGotchi is free and open source. If you like it and want to support development, you can buy me a coffee:

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/FabrizioDeLuca89)

👉 **https://paypal.me/FabrizioDeLuca89** — thank you! 💜

## License

[MIT](LICENSE)
