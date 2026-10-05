# Note design-sync

- App Electron, nessuna libreria componenti: bundle fatto a mano da `.design-sync/build.sh` (niente converter/storybook).
- Fonte di verità degli stili: `windows/theme.css` (token), `windows/dashboard.css`, `windows/pet.css`. Il bundle li copia 1:1 in `tokens/` e `css/`.
- Ritorno da Claude Design: leggere `tokens/theme.css`, `css/dashboard.css`, `css/pet.css` dal progetto e ricopiarli in `windows/`. Se cambiano i colori di stato, aggiornare anche `CG.TINT` in `windows/shared.js`.
- Card preview: `.design-sync/src/components/<gruppo>/<Nome>/<Nome>.html`, prima riga `<!-- @dsCard group="…" -->`.
- `url()` dentro una custom property si risolve rispetto al CSS che usa la var: per gli sprite `background-image` va inline.
- Solo gli sprite idle vengono caricati (assets completi ~32 MB).
