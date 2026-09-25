#!/usr/bin/env python3
# Importa una striscia orizzontale generata (sfondo trasparente) nel formato dell'app.
# Uso: python3 tools/import_sprite.py <striscia.png> <nome> <frame> [--no-eyes]
#   --no-eyes: non riempie il bianco degli occhi (personaggi senza, es. robot)
#   es. python3 tools/import_sprite.py ~/Downloads/error.png error 8
# Scrive windows/assets/<nome>_1x<frame>.png.
import re
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

RES = Path(__file__).resolve().parent.parent / "windows/assets"
PAD = 8
HOLE_MAX = 4000  # buchi trasparenti chiusi più piccoli di così = bianco degli occhi
# ponytail: fascia occhi fissa (y 45-57% dell'altezza), tarata sulle strisce chibi attuali
EYES = "--no-eyes" not in sys.argv


def clean(f):
    px = np.array(f)
    opaque = px[..., 3] > 10
    # Via i frammenti dei frame vicini: piccoli pezzi che toccano i bordi del taglio.
    lab, n = ndimage.label(opaque)
    if n:
        areas = ndimage.sum(opaque, lab, range(1, n + 1))
        for i in (set(lab[:, 0]) | set(lab[:, -1])) - {0}:
            if areas[i - 1] < areas.max() * 0.15:
                px[lab == i] = 0
    if not EYES:
        return Image.fromarray(px)
    # Riempie di bianco i piccoli buchi trasparenti chiusi all'altezza degli occhi.
    hole, n = ndimage.label(px[..., 3] <= 10)
    border = set(hole[0]) | set(hole[-1]) | set(hole[:, 0]) | set(hole[:, -1])
    h = px.shape[0]
    for i, sl in enumerate(ndimage.find_objects(hole), 1):
        if i not in border and 0.45 * h <= sl[0].start <= 0.57 * h and (hole == i).sum() < HOLE_MAX:
            px[hole == i] = (255, 255, 255, 255)
    return Image.fromarray(px)


def slice_strip(im, n):
    w, h = im.size
    opaque = np.array(im.getchannel("A")) > 10
    # Solo la fascia del corpo (righe dense): sopra la testa e tra le antenne
    # c'è vuoto, che altrimenti sembra un confine tra frame.
    rows = opaque.sum(1)
    ink = opaque[rows >= rows.max() * 0.5].sum(0)
    # Media mobile: fumo, scritte e ciocche sottili non creano falsi minimi.
    ink = np.convolve(ink, np.ones(9) / 9, mode="same")
    # Taglio sulla colonna con meno inchiostro vicino al confine ideale
    # (±35%: i generatori non rispettano il passo dichiarato).
    cuts = [0]
    for k in range(1, n):
        c, r = w * k // n, int(w / n * 0.35)
        cuts.append(min(range(c - r, c + r), key=lambda x: (ink[x], abs(x - c))))
    cuts.append(w)
    frames = [clean(im.crop((cuts[k], 0, cuts[k + 1], h))) for k in range(n)]
    frames = [f.crop(f.getbbox()) for f in frames]
    cw = max(f.width for f in frames) + PAD * 2
    ch = max(f.height for f in frames) + PAD * 2
    strip = Image.new("RGBA", (cw * n, ch))
    for k, f in enumerate(frames):
        # Centrato in orizzontale, appoggiato in basso: il personaggio non "salta".
        strip.paste(f, (k * cw + (cw - f.width) // 2, ch - PAD - f.height), f)
    return strip


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--no-eyes"]
    if len(args) != 3:
        sys.exit("uso: import_sprite.py <striscia.png> <nome> <frame> [--no-eyes]")
    src, name, n = args[0], args[1], int(args[2])
    for old in RES.glob(f"{name}_*.png"):
        if re.fullmatch(rf"{re.escape(name)}_\d+x\d+", old.stem):
            old.unlink()  # un solo file per nome, altrimenti il catalogo li mostra doppi
    out = RES / f"{name}_1x{n}.png"
    slice_strip(Image.open(src).convert("RGBA"), n).save(out, optimize=True)
    print("scritto", out)
