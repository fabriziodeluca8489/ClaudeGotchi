const { app, BrowserWindow, Menu, Tray, ipcMain, screen, nativeImage, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const http = require('http');
const { execFile } = require('child_process');
const CG = require('./shared');

const PORT = 47823;
const MARK = 'app=claudegotchi'; // riconosce le nostre voci in settings.json
const EVENTS = { PreToolUse: 'pre', PostToolUse: 'post', Stop: 'stop', Notification: 'notification' };

if (!app.requestSingleInstanceLock()) app.quit();

// ---------- Impostazioni ----------
const settingsFile = () => path.join(app.getPath('userData'), 'settings.json');
let settings = { ...CG.DEFAULTS };
function loadSettings() {
  try { settings = { ...CG.DEFAULTS, ...JSON.parse(fs.readFileSync(settingsFile(), 'utf8')) }; } catch {}
}
function saveSettings() {
  try { fs.mkdirSync(path.dirname(settingsFile()), { recursive: true }); fs.writeFileSync(settingsFile(), JSON.stringify(settings)); } catch {}
}

// ---------- Catalogo sprite: assets/<nome>_<righe>x<colonne>.png ----------
function loadCatalog() {
  return fs.readdirSync(path.join(__dirname, 'assets'))
    .map((f) => f.match(/^(.+)_(\d+)x(\d+)\.png$/))
    .filter(Boolean)
    .map((m) => ({ file: m[0].slice(0, -4), name: m[1], rows: +m[2], cols: +m[3] }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ---------- Limiti: ~/.claude/rate-cache.json, scritto dalla statusline di Claude Code ----------
const rateFile = () => path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'), 'rate-cache.json');
let rate = { r5: 0, r7: 0, r5ResetsAt: 0, r7ResetsAt: 0, contextPct: 0, model: '' };
function loadRate() {
  let j = {};
  try { j = JSON.parse(fs.readFileSync(rateFile(), 'utf8')); } catch {}
  const n = (v) => Number(v) || 0; // i reset possono essere stringa o numero
  const next = { r5: n(j.r5), r7: n(j.r7), r5ResetsAt: n(j.r5_resets_at), r7ResetsAt: n(j.r7_resets_at), contextPct: n(j.context_pct), model: j.model || '' };
  if (JSON.stringify(next) !== JSON.stringify(rate)) { rate = next; broadcast('rate', rate); }
}

// Fallback senza statusline (es. estensione VS Code): un messaggio minimo in `claude -p` emette un
// rate_limit_event con l'utilizzo 5h/7d. --setting-sources "" evita che partano gli hook del pet.
// ponytail: costa un messaggio haiku ogni PROBE_MS, solo se rate-cache.json e' piu' vecchio.
const PROBE_MS = 10 * 60 * 1000;
function probeRate() {
  let mtime = 0;
  try { mtime = fs.statSync(rateFile()).mtimeMs; } catch {}
  if (Date.now() - mtime < PROBE_MS && rate.r5ResetsAt > 0) return; // senza orari di reset il dato vale come vecchio
  execFile('claude', ['-p', 'ok', '--model', 'haiku', '--setting-sources', '', '--output-format', 'stream-json', '--verbose'],
    { cwd: os.tmpdir(), timeout: 60000, maxBuffer: 1 << 24, shell: process.platform === 'win32' }, (err, out) => {
      const line = String(out || '').split('\n').find((l) => l.includes('"rate_limit_event"'));
      if (!line) return;
      try {
        const w = JSON.parse(line).rate_limit_info.unifiedWindows;
        let old = {};
        try { old = JSON.parse(fs.readFileSync(rateFile(), 'utf8')); } catch {}
        const pct = (x) => Math.round(((x && x.utilization) || 0) * 100); // utilization: frazione 0-1
        fs.writeFileSync(rateFile(), JSON.stringify({
          ...old, r5: pct(w.five_hour), r7: pct(w.seven_day),
          r5_resets_at: String((w.five_hour || {}).resetsAt || ''), r7_resets_at: String((w.seven_day || {}).resetsAt || ''),
          ts: Math.floor(Date.now() / 1000),
        }));
      } catch {}
    });
}

// ---------- Stato (equivalente degli hook bash) ----------
let state = { state: 'idle', tool: '', taskSummary: '', tokensInput: 0, tokensOutput: 0, toolCalls: 0, sessionId: '', timestamp: new Date().toISOString() };
let eventCount = 0;
let doneTimer;

// Token dal transcript JSONL: contesto = ultimo messaggio assistant, output = somma.
function tokensFrom(file) {
  try {
    let ctx = 0, out = 0;
    for (const l of fs.readFileSync(file, 'utf8').split('\n')) {
      if (!l) continue;
      let j; try { j = JSON.parse(l); } catch { continue; }
      const u = j.type === 'assistant' && j.message && j.message.usage;
      if (!u) continue;
      ctx = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
      out += u.output_tokens || 0;
    }
    return [ctx, out];
  } catch { return [0, 0]; }
}

function handleHook(ev, body) {
  const sid = body.session_id || '';
  if (sid !== state.sessionId) state = { ...state, toolCalls: 0, tokensInput: 0, tokensOutput: 0 };
  clearTimeout(doneTimer);
  const patch = {};
  if (ev === 'pre') Object.assign(patch, { state: 'working', tool: body.tool_name || '' });
  else if (ev === 'post') {
    const [ctx, out] = tokensFrom(body.transcript_path);
    Object.assign(patch, { state: 'working', toolCalls: state.toolCalls + 1, tokensInput: ctx, tokensOutput: out });
  } else if (ev === 'stop') {
    const [ctx, out] = tokensFrom(body.transcript_path);
    Object.assign(patch, { state: 'done', tool: '', tokensInput: ctx, tokensOutput: out });
    // Dopo 5s torna idle, se nel frattempo non è cambiato nulla.
    doneTimer = setTimeout(() => setState({ state: 'idle' }), 5000);
  } else if (ev === 'notification') patch.state = 'waiting';
  else return;
  eventCount++;
  setState({ ...patch, sessionId: sid });
}

function setState(patch) {
  state = { ...state, ...patch, timestamp: new Date().toISOString() };
  broadcast('state', state);
}

function broadcast(ch, v) {
  for (const w of BrowserWindow.getAllWindows()) w.webContents.send(ch, v);
}

// Server locale: gli hook di Claude Code fanno POST del loro JSON qui.
function startServer() {
  http.createServer((req, res) => {
    let data = '';
    req.on('data', (c) => (data += c));
    req.on('end', () => {
      try { handleHook(req.url.split('?')[0].replace('/hook/', ''), JSON.parse(data || '{}')); } catch {}
      res.writeHead(204).end();
    });
  }).on('error', () => {}).listen(PORT, '127.0.0.1');
}

// ---------- Hook in ~/.claude/settings.json ----------
const settingsPath = () => path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'), 'settings.json');
const CURL = process.platform === 'win32' ? 'curl.exe' : 'curl';
const hookCmd = (ev) => `${CURL} -s -m 2 -X POST --data-binary @- "http://127.0.0.1:${PORT}/hook/${ev}?${MARK}"`;

function readClaudeSettings() {
  try { return JSON.parse(fs.readFileSync(settingsPath(), 'utf8')); } catch { return {}; }
}
const isOurs = (h) => typeof h.command === 'string' && h.command.includes(MARK);

// Statusline: fornisce i limiti 5h/7d. Non sovrascrive una statusline dell'utente.
const SL_NAME = 'claudegotchi-statusline.js';
function patchStatusLine(json, add) {
  const ours = json.statusLine && String(json.statusLine.command || '').includes(SL_NAME);
  const dest = path.join(path.dirname(settingsPath()), SL_NAME);
  if (add && (!json.statusLine || ours)) {
    fs.writeFileSync(dest, fs.readFileSync(path.join(__dirname, 'statusline.js'))); // copia fuori dall'asar
    json.statusLine = { type: 'command', command: `node "${dest}"` };
  } else if (!add && ours) {
    delete json.statusLine;
    try { fs.unlinkSync(dest); } catch {}
  }
}

function patchHooks(add) {
  const p = settingsPath();
  const json = readClaudeSettings();
  fs.mkdirSync(path.dirname(p), { recursive: true });
  // Backup una sola volta: non sovrascrive quello pristino.
  if (fs.existsSync(p) && !fs.existsSync(p + '.bak')) fs.copyFileSync(p, p + '.bak');
  const hooks = json.hooks || {};
  for (const [event, ev] of Object.entries(EVENTS)) {
    let arr = (hooks[event] || [])
      .map((g) => ({ ...g, hooks: (g.hooks || []).filter((h) => !isOurs(h)) }))
      .filter((g) => g.hooks.length);
    if (add) arr.push({ hooks: [{ type: 'command', command: hookCmd(ev) }] });
    if (arr.length) hooks[event] = arr; else delete hooks[event];
  }
  if (Object.keys(hooks).length) json.hooks = hooks; else delete json.hooks;
  patchStatusLine(json, add);
  fs.writeFileSync(p, JSON.stringify(json, null, 2));
}
function hooksInstalled() {
  const hooks = readClaudeSettings().hooks || {};
  return Object.keys(EVENTS).every((e) => (hooks[e] || []).some((g) => (g.hooks || []).some(isOurs)));
}

// ---------- Finestre ----------
let pet, dash, tray, dragStart;
const web = { preload: path.join(__dirname, 'preload.js'), contextIsolation: true };

function petSize() { const sc = CG.sizeOf(settings).scale; return [Math.round(120 * sc), Math.round(150 * sc)]; }

function createPet() {
  const [w, h] = petSize();
  const { workArea } = screen.getPrimaryDisplay();
  pet = new BrowserWindow({
    width: w, height: h, x: workArea.x + workArea.width - w - 24, y: workArea.y + 24,
    frame: false, transparent: true, resizable: false, skipTaskbar: true, hasShadow: false,
    alwaysOnTop: true, webPreferences: web,
  });
  pet.setAlwaysOnTop(true, 'screen-saver');
  pet.loadFile('pet.html');
}

function openDashboard() {
  if (dash && !dash.isDestroyed()) return dash.focus();
  dash = new BrowserWindow({ width: 1040, height: 700, minWidth: 900, minHeight: 620, title: 'ClaudeGotchi — Dashboard', backgroundColor: '#100e17', icon: path.join(__dirname, 'icon.png'), autoHideMenuBar: true, webPreferences: web });
  dash.loadFile('dashboard.html');
}

function buildMenu() {
  const set = (p) => () => updateSettings(p);
  return Menu.buildFromTemplate([
    { label: 'Skin', submenu: CG.SKINS.map((s) => ({ label: s.label, type: 'radio', checked: settings.skin === s.id, click: set({ skin: s.id }) })) },
    { label: 'Dimensione', submenu: CG.SIZES.map((s) => ({ label: s.label, type: 'radio', checked: settings.size === s.id, click: set({ size: s.id }) })) },
    { label: 'Dashboard…', click: openDashboard },
    { label: '☕ Dona con PayPal…', click: () => shell.openExternal(CG.DONATE_URL) },
    { type: 'separator' },
    hooksInstalled()
      ? { label: 'Rimuovi hook Claude Code', click: () => patchHooks(false) }
      : { label: 'Installa hook Claude Code', click: () => patchHooks(true) },
    { type: 'separator' },
    { label: 'Esci', click: () => app.quit() },
  ]);
}

function updateSettings(patch) {
  settings = { ...settings, ...patch };
  saveSettings();
  if (patch.size && pet) pet.setSize(...petSize());
  broadcast('settings', settings);
}

// ---------- IPC ----------
ipcMain.handle('init', () => ({ settings, state, catalog: loadCatalog(), hooks: hooksInstalled(), eventCount, rate }));
ipcMain.handle('set', (_, p) => updateSettings(p));
ipcMain.handle('reset-anim', () => updateSettings({ anim: {}, fps: {} }));
ipcMain.handle('hooks:status', () => ({ hooks: hooksInstalled(), eventCount }));
ipcMain.handle('hooks:install', () => { patchHooks(true); return hooksInstalled(); });
ipcMain.handle('hooks:uninstall', () => { patchHooks(false); return hooksInstalled(); });
ipcMain.on('drag-start', (_, x, y) => { dragStart = { x, y, pos: pet.getPosition() }; });
ipcMain.on('drag-move', (_, x, y) => {
  if (dragStart) pet.setPosition(dragStart.pos[0] + x - dragStart.x, dragStart.pos[1] + y - dragStart.y);
});
ipcMain.on('menu', () => buildMenu().popup({ window: pet }));
ipcMain.on('donate', () => shell.openExternal(CG.DONATE_URL));
ipcMain.on('beep', () => shell.beep());

app.whenReady().then(() => {
  loadSettings();
  startServer();
  loadRate(); fs.watchFile(rateFile(), { interval: 2000 }, loadRate);
  probeRate(); setInterval(probeRate, PROBE_MS);
  if (process.platform === 'darwin') app.dock.setIcon(path.join(__dirname, 'icon.png'));
  createPet();
  tray = new Tray(nativeImage.createFromPath(path.join(__dirname, 'tray.png')).resize({ width: 16, height: 16 }));
  tray.setToolTip('ClaudeGotchi');
  tray.on('click', openDashboard);
  tray.on('right-click', () => tray.popUpContextMenu(buildMenu()));
  // Al primo avvio apre la dashboard, dove si installano gli hook.
  if (!hooksInstalled()) openDashboard();
});
app.on('window-all-closed', (e) => e.preventDefault()); // resta nel tray
