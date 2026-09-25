// Animazione di una striscia sprite (1 riga, N colonne) dentro un contenitore.
const dimsCache = {};
function loadDims(file) {
  if (dimsCache[file]) return dimsCache[file];
  return (dimsCache[file] = new Promise((res) => {
    const im = new Image();
    im.onload = () => res([im.naturalWidth, im.naturalHeight]);
    im.onerror = () => res([1, 1]);
    im.src = `assets/${file}.png`;
  }));
}

class SpriteEl {
  constructor(host) {
    this.host = host;
    this.div = document.createElement('div');
    host.style.display = 'flex';
    host.style.alignItems = 'center';
    host.style.justifyContent = 'center';
    host.appendChild(this.div);
    this.frame = 0;
  }
  async set(sheet, fps) {
    if (!sheet) return;
    const key = sheet.file + '@' + fps + '@' + this.host.clientWidth;
    if (key === this.key) return;
    this.key = key;
    const [w, h] = await loadDims(sheet.file);
    if (key !== this.key) return; // arrivato un set più recente
    const r = w / sheet.cols / h;
    const bw = this.host.clientWidth, bh = this.host.clientHeight;
    const fw = r >= 1 ? bw : bh * r, fh = r >= 1 ? bw / r : bh;
    Object.assign(this.div.style, {
      width: fw + 'px', height: fh + 'px',
      backgroundImage: `url(assets/${sheet.file}.png)`,
      backgroundSize: `${sheet.cols * 100}% 100%`, backgroundRepeat: 'no-repeat',
    });
    clearInterval(this.timer);
    this.frame = 0;
    const draw = () => {
      const x = sheet.cols > 1 ? (this.frame / (sheet.cols - 1)) * 100 : 0;
      this.div.style.backgroundPosition = `${x}% 0`;
      this.frame = (this.frame + 1) % sheet.cols;
    };
    draw();
    this.timer = setInterval(draw, 1000 / fps);
  }
}
