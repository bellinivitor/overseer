#!/bin/bash
# Compila o Overseer.app (menu bar). Não precisa de root nem de Xcode project.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

echo "==> compilando Overseer.app"
APP="build/Overseer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compila todos os .swift de app/ num único binário.
# -parse-as-library: exige um @main explícito (sem isso, um único arquivo vira
# "script mode" e conflita com @main).
swiftc -O -parse-as-library app/*.swift -o "$APP/Contents/MacOS/Overseer"

# Ícone do app (Spotlight, Finder, Dock, etc.), se já tiver sido gerado.
if [ -f icon/AppIcon.icns ]; then
    cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Overseer</string>
    <key>CFBundleDisplayName</key>     <string>Overseer</string>
    <key>CFBundleIdentifier</key>      <string>com.bellini.overseer</string>
    <key>CFBundleVersion</key>         <string>0.1.1</string>
    <key>CFBundleShortVersionString</key><string>0.1.1</string>
    <key>CFBundleExecutable</key>      <string>Overseer</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

# Assinatura ad-hoc: deixa o app rodar localmente sem alertas de "app danificado".
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "==> pronto:"
echo "    build/Overseer.app"
echo ""
echo "Para abrir:  open build/Overseer.app"
