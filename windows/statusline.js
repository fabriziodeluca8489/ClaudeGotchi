// Statusline per Claude Code (Windows): scrive ~/.claude/rate-cache.json e stampa una riga di stato.
// Equivalente di statusline.sh su Mac. Legge il payload JSON da stdin.
const fs = require('fs');
const os = require('os');
const path = require('path');

let p = {};
try { p = JSON.parse(fs.readFileSync(0, 'utf8')); } catch {}

const rl = p.rate_limits || {};
const five = rl.five_hour || {}, seven = rl.seven_day || {};
const model = (p.model && (p.model.display_name || p.model.id)) || 'Claude';
const ctx = Math.round((p.context_window && p.context_window.used_percentage) || 0);
const r5 = Math.round(five.used_percentage || 0), r7 = Math.round(seven.used_percentage || 0);

try {
  const dir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  fs.writeFileSync(path.join(dir, 'rate-cache.json'), JSON.stringify({
    r5, r7,
    r5_resets_at: five.resets_at == null ? '' : String(five.resets_at),
    r7_resets_at: seven.resets_at == null ? '' : String(seven.resets_at),
    context_pct: ctx, model,
    cwd: (p.workspace && p.workspace.current_dir) || p.cwd || '',
    ts: Math.floor(Date.now() / 1000),
  }));
} catch {}

console.log(`${model} │ ctx ${ctx}% │ Session:${r5}% │ Weekly:${r7}%`);
