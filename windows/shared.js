// Definizioni condivise tra processo main e finestre (skin, attività, default).
(function (root) {
  // Lingua UI: italiano se il sistema è in italiano, altrimenti inglese.
  // Renderer: navigator.language; main: setLang(app.getLocale()) quando l'app è pronta.
  let lang = 'en';
  const setLang = (l) => { lang = /^it/i.test(l || '') ? 'it' : 'en'; };
  if (typeof navigator !== 'undefined') setLang(navigator.language);
  const tr = (it, en) => (lang === 'it' ? it : en);
  // label calcolata al momento dell'uso, nella lingua corrente
  const labeled = (arr) => arr.map((o) => Object.defineProperty(o, 'label', { get: () => tr(o.it, o.en) }));

  const SKINS = labeled([
    { id: 'dev', it: 'Sviluppatore', en: 'Developer', prefix: '' },
    { id: 'bot', it: 'Robot', en: 'Robot', prefix: 'robot_' },
    { id: 'star', it: 'Star Puccioso', en: 'Star Puccioso', prefix: 'star_' },
    { id: 'red', it: 'Peluche Rosso', en: 'Peluche Rosso', prefix: 'red_' },
  ]);
  const SIZES = labeled([
    { id: 'small', it: 'Piccolo', en: 'Small', scale: 0.75 },
    { id: 'medium', it: 'Medio', en: 'Medium', scale: 1 },
    { id: 'large', it: 'Grande', en: 'Large', scale: 1.5 },
    { id: 'xlarge', it: 'Molto grande', en: 'Extra large', scale: 2 },
  ]);
  const ACTIVITIES = labeled([
    { id: 'idle', it: 'In attesa', en: 'Idle', sheet: 'idle' },
    { id: 'sleeping', it: 'Dorme (inattivo)', en: 'Sleeping (inactive)', sheet: 'sleep' },
    { id: 'reading', it: 'Legge (Read/Grep/Glob)', en: 'Reading (Read/Grep/Glob)', sheet: 'reading' },
    { id: 'writing', it: 'Scrive (Edit/Write)', en: 'Writing (Edit/Write)', sheet: 'writing_code' },
    { id: 'bash', it: 'Terminale (Bash)', en: 'Terminal (Bash)', sheet: 'terminal' },
    { id: 'working', it: 'Al lavoro (altri tool)', en: 'Working (other tools)', sheet: 'working' },
    { id: 'waiting', it: 'Attende permesso', en: 'Waiting for permission', sheet: 'waiting_permission' },
    { id: 'done', it: 'Finito', en: 'Done', sheet: 'done' },
    { id: 'error', it: 'Errore', en: 'Error', sheet: 'error' },
  ]);
  const DONATE_URL = 'https://paypal.me/FabrizioDeLuca89';
  const TINT = { idle: '#4dc7b3', working: '#528cf2', waiting: '#f2a640', done: '#59cc66', error: '#e65959' };
  const BGS = labeled([
    { id: 'stato', it: 'Stato', en: 'Status' },
    { id: 'notte', it: 'Notte', en: 'Night', color: '#141424' },
    { id: 'nebbia', it: 'Nebbia', en: 'Fog', color: '#e0e0eb' },
  ]);
  const INFO = labeled([
    { id: 'caption', it: 'Didascalia stato', en: 'Status caption' },
    { id: 'tool', it: 'Nome tool in uso', en: 'Current tool name' },
    { id: 'ctxTokens', it: 'Token contesto', en: 'Context tokens' },
    { id: 'outTokens', it: 'Token output', en: 'Output tokens' },
    { id: 'toolCalls', it: 'Tool calls', en: 'Tool calls' },
    { id: 'limit5h', it: 'Limite 5h', en: '5h limit' },
    { id: 'limit7d', it: 'Limite 7 giorni', en: '7-day limit' },
    { id: 'ctxPct', it: 'Contesto %', en: 'Context %' },
    { id: 'model', it: 'Modello', en: 'Model' },
  ]);
  const DEFAULTS = {
    skin: 'dev', size: 'medium', showStats: true, statsAlways: false,
    bgTransparent: true, bgColor: 'stato', anim: {}, fps: {},
    info: ['caption', 'tool', 'limit5h', 'limit7d', 'ctxPct'], sleepMinutes: 10,
  };

  const skinOf = (s) => SKINS.find((k) => k.id === s.skin) || SKINS[0];
  const sizeOf = (s) => SIZES.find((k) => k.id === s.size) || SIZES[1];

  // Attività mostrata: stato hook + tool + inattività.
  function activityFrom(st, now, sleepAfterMs) {
    switch (st.state) {
      case 'idle': {
        const t = Date.parse(st.timestamp);
        return t && now - t > sleepAfterMs ? 'sleeping' : 'idle';
      }
      case 'working':
        if (['Read', 'Grep', 'Glob', 'WebFetch', 'WebSearch'].includes(st.tool)) return 'reading';
        if (['Edit', 'Write', 'MultiEdit', 'NotebookEdit'].includes(st.tool)) return 'writing';
        if (st.tool === 'Bash') return 'bash';
        return 'working';
      case 'waiting': return 'waiting';
      case 'done': return 'done';
      case 'error': return 'error';
      default: return 'idle';
    }
  }

  function sheetFor(s, catalog, a) {
    const p = skinOf(s).prefix;
    const named = (n) => catalog.find((c) => c.file === n || c.name === n);
    const def = ACTIVITIES.find((x) => x.id === a).sheet;
    return named(s.anim[p + a]) || named(p + def) || named(p + 'idle') || catalog[0];
  }
  const fpsFor = (s, a) => s.fps[skinOf(s).prefix + a] || 3;

  // Righe statistiche scelte (max 3, come su Mac). Limite con reset passato = dato stantio -> "—".
  const compact = (n) => (n >= 1000 ? (n / 1000).toFixed(1) + 'k' : String(n));
  const pad = (n) => String(n).padStart(2, '0');
  function statRows(st, rate, info, now = Date.now()) {
    const limit = (label, pct, at, fmt) => {
      const stale = at > 0 && at * 1000 < now;
      const d = new Date(at * 1000);
      const reset = stale || !at ? '' : '→' + (fmt === 'time' ? `${pad(d.getHours())}:${pad(d.getMinutes())}` : `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`);
      return [label, stale ? '—' : String(pct), reset];
    };
    const all = {
      ctxTokens: () => ['ctx', compact(st.tokensInput), ''],
      outTokens: () => ['out', compact(st.tokensOutput), ''],
      toolCalls: () => ['tool', String(st.toolCalls), ''],
      limit5h: () => limit('5h', rate.r5, rate.r5ResetsAt, 'time'),
      limit7d: () => limit('7d', rate.r7, rate.r7ResetsAt, 'date'),
      ctxPct: () => ['ctx', rate.contextPct + '%', ''],
      model: () => ['mod', rate.model || '—', ''],
    };
    return Object.keys(all).filter((k) => info.includes(k)).slice(0, 3).map((k) => all[k]());
  }

  const api = { tr, setLang, statRows, DONATE_URL, SKINS, SIZES, ACTIVITIES, TINT, BGS, INFO, DEFAULTS, skinOf, sizeOf, activityFrom, sheetFor, fpsFor };
  if (typeof module !== 'undefined') module.exports = api; else root.CG = api;
})(this);
