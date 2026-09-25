// Definizioni condivise tra processo main e finestre (skin, attività, default).
(function (root) {
  const SKINS = [
    { id: 'dev', label: 'Sviluppatore', prefix: '' },
    { id: 'bot', label: 'Robot', prefix: 'robot_' },
    { id: 'star', label: 'Star Puccioso', prefix: 'star_' },
  ];
  const SIZES = [
    { id: 'small', label: 'Piccolo', scale: 0.75 },
    { id: 'medium', label: 'Medio', scale: 1 },
    { id: 'large', label: 'Grande', scale: 1.5 },
    { id: 'xlarge', label: 'Molto grande', scale: 2 },
  ];
  const ACTIVITIES = [
    { id: 'idle', label: 'In attesa', sheet: 'idle' },
    { id: 'sleeping', label: 'Dorme (inattivo)', sheet: 'sleep' },
    { id: 'reading', label: 'Legge (Read/Grep/Glob)', sheet: 'reading' },
    { id: 'writing', label: 'Scrive (Edit/Write)', sheet: 'writing_code' },
    { id: 'bash', label: 'Terminale (Bash)', sheet: 'terminal' },
    { id: 'working', label: 'Al lavoro (altri tool)', sheet: 'working' },
    { id: 'waiting', label: 'Attende permesso', sheet: 'waiting_permission' },
    { id: 'done', label: 'Finito', sheet: 'done' },
    { id: 'error', label: 'Errore', sheet: 'error' },
  ];
  const DONATE_URL = 'https://paypal.me/FabrizioDeLuca89';
  const TINT = { idle: '#4dc7b3', working: '#528cf2', waiting: '#f2a640', done: '#59cc66', error: '#e65959' };
  const BGS = [
    { id: 'stato', label: 'Stato' },
    { id: 'notte', label: 'Notte', color: '#141424' },
    { id: 'nebbia', label: 'Nebbia', color: '#e0e0eb' },
  ];
  const INFO = [
    { id: 'caption', label: 'Didascalia stato' },
    { id: 'tool', label: 'Nome tool in uso' },
    { id: 'ctxTokens', label: 'Token contesto' },
    { id: 'outTokens', label: 'Token output' },
    { id: 'toolCalls', label: 'Tool calls' },
    { id: 'limit5h', label: 'Limite 5h' },
    { id: 'limit7d', label: 'Limite 7 giorni' },
    { id: 'ctxPct', label: 'Contesto %' },
    { id: 'model', label: 'Modello' },
  ];
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
  const fpsFor = (s, a) => s.fps[skinOf(s).prefix + a] || 8;

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

  const api = { statRows, DONATE_URL, SKINS, SIZES, ACTIVITIES, TINT, BGS, INFO, DEFAULTS, skinOf, sizeOf, activityFrom, sheetFor, fpsFor };
  if (typeof module !== 'undefined') module.exports = api; else root.CG = api;
})(this);
