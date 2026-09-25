#!/usr/bin/env bash
# Compila in release e assembla ClaudeGotchi.app pronto per /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=".build/release/ClaudeGotchi"

APP="ClaudeGotchi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ClaudeGotchi"

# Copia resource bundle generato da SwiftPM (sprite sheet ecc.)
# Bundle.module cerca in Bundle.main.bundleURL (root della .app)
# Cerca il bundle senza assumere l'architettura (arm64 o x86_64)
BUNDLE="$(find .build -iname 'ClaudeGotchi_ClaudeGotchi.bundle' -ipath '*release*' | head -n1)"
if [ -n "$BUNDLE" ] && [ -d "$BUNDLE" ]; then
    cp -r "$BUNDLE" "$APP/"
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ClaudeGotchi</string>
  <key>CFBundleDisplayName</key><string>ClaudeGotchi</string>
  <key>CFBundleIdentifier</key><string>com.claudegotchi.app</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>ClaudeGotchi</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Firma ad-hoc: permette l'avvio locale (tasto destro -> Apri) senza account Apple Developer.
# Non fatale: il bundle risorse sta fuori da Contents/ (richiesto da Bundle.module) e
# fa scattare un warning "unsealed contents" che non impedisce comunque l'esecuzione locale.
codesign --force --deep --sign - "$APP" || true

echo "Creato $APP — trascinalo in /Applications."
