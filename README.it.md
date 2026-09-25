# ClaudeGotchi 🐣

🇮🇹 Italiano · [🇬🇧 English](README.md)

Un compagno animato che vive sul desktop, sempre sopra le altre finestre, e ti mostra
**cosa sta facendo Claude Code**: se è in attesa, se sta lavorando (legge, scrive, usa il
terminale), se aspetta un tuo permesso o se ha finito. Quando un task termina, il personaggio
salta, lampeggia ed emette un suono, così te ne accorgi anche mentre lavori in un'altra app.

Passando il mouse sul personaggio, vedi le statistiche della sessione: token di contesto,
token di output e tool eseguiti.

- 4 personaggi: **Sviluppatore**, **Robot**, **Star Puccioso**, **Peluche Rosso**
- 9 animazioni (una per attività), con sprite e FPS configurabili
- Dashboard con anteprima live e scelta di dimensioni, sfondi e informazioni da mostrare
- Realizzato con **Electron**: funziona su **Windows** e **macOS**

## Come funziona

```
Claude Code ──hook──▶ ClaudeGotchi ──▶ personaggio animato
```

Quattro hook di Claude Code (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`) comunicano
lo stato all'app. I token vengono letti dal transcript della sessione. Tutto resta sul tuo
computer: l'app riceve gli hook via `curl` su `127.0.0.1:47823`.

## Installazione

### Windows e macOS

Requisiti: [Node.js](https://nodejs.org) 18+ e `curl` (incluso in Windows 10/11 e macOS).

```bash
cd windows
npm install
npm run build:win     # Windows -> windows/dist/ClaudeGotchi.exe (portable)
npm run build:mac     # macOS   -> windows/dist/*.zip
npm start             # oppure avvio diretto senza build
```

Avvia l'app: la prima volta si apre la Dashboard. Nella sezione *Claude Code* clicca **Installa**
(aggiunge 4 hook al tuo `~/.claude/settings.json`, con un backup in `settings.json.bak`), poi
**riavvia le sessioni di Claude Code già aperte**. Se compare l'avviso di Windows SmartScreen,
scegli "Ulteriori informazioni" → "Esegui comunque" (l'app non è firmata).

## Uso

- **Trascina** il personaggio dove vuoi. Con il **clic destro** apri il menu (skin, dimensione,
  Dashboard, hook, dona, esci).
- **Dashboard**: animazione e FPS per ogni attività, skin, dimensione, sfondo, informazioni da
  mostrare (didascalia, tool, token, tool calls) e minuti di inattività prima che si addormenti.
- **Attività**: in attesa, dorme, legge (Read/Grep/Glob), scrive (Edit/Write), terminale (Bash),
  al lavoro (altri tool), attende permesso, finito, errore.

## Nuove animazioni

Le animazioni sono strisce orizzontali di sprite con sfondo trasparente, salvate in
`windows/assets/<personaggio>/` (`dev`, `bot`, `star`, `red`) con il nome `<nome>_<righe>x<colonne>.png` (es. `idle_1x8.png`).
L'app ricava la griglia dal nome del file e mostra tutte le animazioni nella Dashboard.
Nomi predefiniti per ogni stato: `idle`, `sleep`, `reading`, `writing_code`, `terminal`,
`working`, `waiting_permission`, `done`, `error`. Ogni personaggio animato ha un proprio
prefisso: nessuno per lo Sviluppatore, `robot_` per il Robot (es. `robot_idle_1x8.png`), `star_` per la Star, `red_` per il Peluche Rosso.

Una striscia grezza (con frame irregolari o sovrapposti) si importa così:

```bash
python3 tools/import_sprite.py ~/Downloads/error.png dev/error 8   # file, cartella/nome, n. frame
```

Lo script separa i singoli personaggi, elimina i frammenti dei frame vicini, riempie il
bianco degli occhi e allinea i frame in basso. Per i personaggi senza bianco degli occhi
(come il Robot) aggiungi `--no-eyes`.

Se aggiungi una skin, registrala in `windows/shared.js` (`SKINS`).

## Struttura

```
windows/                # app Electron (Windows/macOS): main.js, pet.html, dashboard.html, assets/
tools/import_sprite.py  # importa una striscia di sprite generata
```

## ☕ Dona

ClaudeGotchi è gratuito e open source. Se ti piace e vuoi sostenerne lo sviluppo, puoi offrirmi un caffè:

[![Dona con PayPal](https://img.shields.io/badge/Dona-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/FabrizioDeLuca89)

👉 **https://paypal.me/FabrizioDeLuca89** — grazie! 💜

## Licenza

[MIT](LICENSE)
