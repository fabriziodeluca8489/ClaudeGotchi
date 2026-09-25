# ClaudeGotchi 🐣

Un compagno animato che vive sul desktop, sempre sopra le altre finestre, e ti mostra
**cosa sta facendo Claude Code**: in attesa, al lavoro (legge, scrive, usa il terminale),
in attesa di un tuo permesso, finito. Quando un task termina salta, lampeggia e suona,
così te ne accorgi anche se stai lavorando in un'altra app.

Passando il mouse sul personaggio vedi le statistiche della sessione: token di contesto,
token di output e tool eseguiti.

- 3 personaggi: **Sviluppatore**, **Robot**, **Star Puccioso**
- 9 animazioni (una per attività), con sprite e FPS configurabili
- Dashboard con anteprima live, dimensioni, sfondi e info da mostrare
- Due versioni: **nativa macOS** (Swift) e **Electron** per **Windows** e macOS

## Come funziona

```
Claude Code ──hook──▶ ClaudeGotchi ──▶ personaggio animato
```

Quattro hook di Claude Code (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`) notificano lo
stato all'app. I token vengono letti dal transcript della sessione. Tutto resta sul tuo
computer: la versione Electron riceve gli hook via `curl` su `127.0.0.1:47823`, quella nativa
macOS tramite un file JSON in `~/.claude/tamagotchi-state.json`.

## Installazione

### Windows (e macOS) — versione Electron

Requisiti: [Node.js](https://nodejs.org) 18+ e `curl` (incluso in Windows 10/11 e macOS).

```bash
cd windows
npm install
npm run build:win     # Windows -> windows/dist/ClaudeGotchi.exe (portable)
npm run build:mac     # macOS   -> windows/dist/*.zip
npm start             # oppure avvio diretto senza build
```

Avvia l'app: al primo avvio si apre la Dashboard. Nella sezione *Claude Code* clicca **Installa**
(aggiunge 4 hook al tuo `~/.claude/settings.json`, con backup in `settings.json.bak`) e poi
**riavvia le sessioni di Claude Code già aperte**. Se Windows SmartScreen avvisa, scegli
"Ulteriori informazioni" → "Esegui comunque" (l'app non è firmata).

### macOS — versione nativa (Swift)

Requisiti: macOS 13+, Xcode/Swift 6, `jq` (`brew install jq`).

```bash
./build_app.sh                      # crea ClaudeGotchi.app
cp -r ClaudeGotchi.app /Applications/
open /Applications/ClaudeGotchi.app
```

Poi click destro sul personaggio → **Installa hooks Claude Code** (oppure
`ClaudeGotchi --install-hooks`) e riavvia Claude Code. Per rimuoverli: **Rimuovi hooks**.

## Uso

- **Trascina** il personaggio dove vuoi. **Click destro** per il menu (skin, dimensione,
  Dashboard, hook, dona, esci).
- **Dashboard**: animazione e FPS per ogni attività, skin, dimensione, sfondo, info mostrate
  (didascalia, tool, token, tool calls), tempo di inattività prima del sonno.
- **Attività**: in attesa, dorme, legge (Read/Grep/Glob), scrive (Edit/Write), terminale (Bash),
  al lavoro (altri tool), attende permesso, finito, errore.

## Nuove animazioni

Le animazioni sono strisce orizzontali con sfondo trasparente in
`Sources/ClaudeGotchi/Resources/`, chiamate `<nome>_<righe>x<colonne>.png`
(es. `idle_1x8.png`). L'app legge la griglia dal nome e le mostra tutte nella
dashboard. Nomi usati di default per stato: `idle`, `sleep`, `reading`,
`writing_code`, `terminal`, `working`, `waiting_permission`, `done`, `error`.
Ogni personaggio animato ha un prefisso: Sviluppatore nessuno, Robot
`robot_` (es. `robot_idle_1x8.png`).

Una striscia grezza (frame irregolari o sovrapposti) si importa con:

```bash
python3 tools/import_sprite.py ~/Downloads/error.png error 8   # file, nome, n. frame
./build_app.sh
```

Per la versione Electron copia i PNG anche in `windows/assets/` e, se aggiungi una skin, registrala in `windows/shared.js` (`SKINS`).

Lo script taglia tra un personaggio e l'altro, toglie i frammenti dei frame
vicini, riempie il bianco degli occhi e allinea i frame in basso. Per
personaggi senza bianco degli occhi (robot) aggiungi `--no-eyes`.

## Struttura

```
Sources/ClaudeGotchi/   # app nativa macOS (SwiftUI/AppKit)
windows/                # app Electron (Windows/macOS): main.js, pet.html, dashboard.html, assets/
hooks/                  # script bash degli hook (versione nativa) + test_hooks.sh
tools/import_sprite.py  # importa una striscia di sprite generata
```

## ☕ Dona

ClaudeGotchi è gratuito e open source. Se ti piace e vuoi supportare lo sviluppo, puoi offrirmi un caffè:

[![Dona con PayPal](https://img.shields.io/badge/Dona-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/FabrizioDeLuca89)

👉 **https://paypal.me/FabrizioDeLuca89** — grazie! 💜

## Licenza

[MIT](LICENSE)
