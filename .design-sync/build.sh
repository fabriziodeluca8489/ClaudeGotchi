#!/bin/sh
# Assembla ds-bundle/ per Claude Design dai CSS reali dell'app + sorgenti in .design-sync/src.
set -e
cd "$(dirname "$0")/.."
rm -rf ds-bundle && mkdir -p ds-bundle/tokens ds-bundle/css ds-bundle/assets
cp windows/theme.css ds-bundle/tokens/theme.css
cp windows/dashboard.css windows/pet.css .design-sync/src/sprite.css ds-bundle/css/
cp -R .design-sync/src/components ds-bundle/components
# solo gli sprite idle (uno per skin): i fogli completi pesano ~32 MB
for f in dev/idle_1x25 bot/robot_idle_1x25 star/star_idle_1x4 red/red_idle_1x11; do
  mkdir -p "ds-bundle/assets/$(dirname $f)" && cp "windows/assets/$f.png" "ds-bundle/assets/$f.png"
done
cp .design-sync/conventions.md ds-bundle/README.md
cat > ds-bundle/styles.css <<'EOF'
@import "tokens/theme.css";
@import "css/dashboard.css";
@import "css/pet.css";
@import "css/sprite.css";
EOF
echo "ds-bundle pronto"
