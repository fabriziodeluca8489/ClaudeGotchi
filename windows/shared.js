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
  ];
  const DEFAULTS = {
    skin: 'dev', size: 'medium', showStats: true, statsAlways: false,
    bgTransparent: true, bgColor: 'stato', anim: {}, fps: {},
    info: ['caption', 'tool', 'ctxTokens', 'outTokens', 'toolCalls'], sleepMinutes: 10,
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

  const api = { DONATE_URL, SKINS, SIZES, ACTIVITIES, TINT, BGS, INFO, DEFAULTS, skinOf, sizeOf, activityFrom, sheetFor, fpsFor };
  if (typeof module !== 'undefined') module.exports = api; else root.CG = api;
})(this);
