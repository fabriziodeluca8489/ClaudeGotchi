# ClaudeGotchi design system

ClaudeGotchi is a desktop companion for Claude Code (Electron). Two surfaces: a **dashboard window** (dark, glassy panels) and a tiny **pet window** (120×150 px, transparent, an animated character with a status pill / stats chip underneath). UI copy is **Italian or English, following the system language** (Italian system → Italian, anything else → English). Previews show Italian; write new copy in both when relevant.

## Setup
No JS components, no provider. Everything is plain HTML + CSS classes. Link `styles.css` — it imports:
- `tokens/theme.css` — all design tokens (`:root` custom properties). **Source of truth: edit colors here.**
- `css/dashboard.css` — dashboard look. Styles `body` itself (dark radial-gradient background, 22px padding, flex column, `--font-ui` 14px), so a page is already "inside the app".
- `css/pet.css` — pet widget, ID-scoped (`#root`, `#sprite`, `#info`, `#stats`).
- `css/sprite.css` — `.sprite` helper that animates a 1×N sprite strip in pure CSS.

## Tokens (use `var(--…)`, never raw hex)
- Surfaces: `--bg`, `--bg-glow-1`, `--bg-glow-2`, `--panel`, `--chip`, `--surface`, `--surface-2`, `--surface-hover`, `--line`, `--line-strong`
- Text/accent: `--text`, `--chip-text`, `--mut` (secondary/labels), `--acc` (violet #8b7cf6), `--acc-soft`
- State colors: `--st-idle` teal, `--st-working` blue, `--st-waiting` orange, `--st-done` green, `--st-error` red, `--st-off` grey
- Limit bars: `--lim-ok`, `--lim-warn` (≥70%), `--lim-bad` (≥90%)
- Radii: `--r-panel` 20px, `--r-card` 14px, `--r-input` 9px, `--r-pill` 99px. Fonts: `--font-ui`, `--font-mono`

## Class vocabulary (dashboard)
- Layout: `header`, `main` (3-column grid), `.panel` (glass card; first child `h2` = small uppercase muted title), `.grp` (stacked group; `.grp > b` = uppercase section label), `.row` (horizontal flex, gap 10), `.hint`
- `.pill` (rounded chip, add `style="margin:0"` when not trailing) + `.dot` (7px status dot; set `background:var(--st-*)`)
- `.card` (selectable row: `.thumb` 44px + `.t` title + `.s` subtitle; `.card.on` = selected, violet gradient; trailing `<span>` = violet ✓)
- `.stats` grid of `<div><b>value</b><span>LABEL</span></div>`
- Controls: native `button`, `.btn-primary` (violet), `.btn-ghost`, `select`, `input[type=number|range|checkbox]` inside `label`
- Title: `h1` (gradient white→violet) + `.sub` (tiny uppercase muted)

## Pet widget
```html
<div id="root"><div id="sprite">…</div>
  <div id="info" class="working" style="--c:var(--st-working);display:block"><i></i>Edit</div></div>
```
`#info` = status pill (dot pulses when `.working`). `#stats` replaces it on hover: rows `<div class="row" style="--p:42%;--c:linear-gradient(var(--lim-ok),var(--lim-ok))"><span class="k">5h</span><span class="v">42%</span><span class="r">→18:30</span></div>`. Captions: "in attesa", tool name, "tocca a te ✋", "fatto! 🎉", "ops…".

## Characters
Four skins, sprite strips in `assets/`: Sviluppatore `dev/idle_1x25.png` (230×247/frame), Robot `bot/robot_idle_1x25.png` (199×206), Star Puccioso `star/star_idle_1x4.png` (280×280), Peluche Rosso `red/red_idle_1x11.png` (177×304).
```html
<div class="sprite" style="background-image:url(assets/dev/idle_1x25.png);--n:25;--fps:8;width:92px;aspect-ratio:230/247"></div>
```

## Example
```html
<link rel="stylesheet" href="styles.css">
<section class="panel" style="max-width:300px"><h2>SKIN <span class="pill" style="margin:0">4</span></h2>
  <div class="card on"><div class="thumb"></div><div class="t" style="flex:1">Sviluppatore</div><span>✓</span></div>
  <div class="grp"><b>CLAUDE CODE</b><div class="row"><span style="flex:1">Hook installati ✓</span><button class="btn-primary">Installa</button></div></div>
</section>
```
See `components/Screens/Dashboard/Dashboard.html` for the full real screen.
