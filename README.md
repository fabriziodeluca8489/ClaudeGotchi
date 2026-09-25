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
- Built with **Electron**: runs on **Windows** and **macOS**

## How it works

```
Claude Code ──hooks──▶ ClaudeGotchi ──▶ animated character
```

Four Claude Code hooks (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`) report the state
to the app. Token counts are read from the session transcript. Everything stays on your
computer: the app receives hooks via `curl` on `127.0.0.1:47823`.

## Installation

### Windows and macOS

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

> The app interface is currently in Italian.

## Usage

- **Drag** the character anywhere. **Right-click** for the menu (skin, size, Dashboard,
  hooks, donate, quit).
- **Dashboard**: animation and FPS per activity, skin, size, background, info shown
  (caption, tool, tokens, tool calls), idle time before sleeping.
- **Activities**: idle, sleeping, reading (Read/Grep/Glob), writing (Edit/Write),
  terminal (Bash), working (other tools), waiting for permission, done, error.

## Adding animations

Animations are horizontal transparent strips in `windows/assets/`, named
`<name>_<rows>x<columns>.png` (e.g. `idle_1x8.png`). The app reads the grid from the file name
and lists them all in the dashboard. Default names per activity: `idle`, `sleep`, `reading`,
`writing_code`, `terminal`, `working`, `waiting_permission`, `done`, `error`.
Each character has a prefix: Developer none, Robot `robot_`, Star `star_`.

A raw strip (irregular or overlapping frames) can be imported with:

```bash
python3 tools/import_sprite.py ~/Downloads/error.png error 8   # file, name, frame count
```

The script cuts between characters, removes fragments of neighbouring frames, fills the eye
whites and bottom-aligns the frames. For characters without eye whites (robot) add `--no-eyes`.
For a new skin, register it in `windows/shared.js` (`SKINS`).

## Structure

```
windows/                # Electron app (Windows/macOS): main.js, pet.html, dashboard.html, assets/
tools/import_sprite.py  # imports a generated sprite strip
```

## ☕ Donate

ClaudeGotchi is free and open source. If you like it and want to support development, you can buy me a coffee:

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/FabrizioDeLuca89)

👉 **https://paypal.me/FabrizioDeLuca89** — thank you! 💜

## License

[MIT](LICENSE)
