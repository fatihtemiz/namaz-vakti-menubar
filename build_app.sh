#!/bin/bash
# NamazVakti menü bar uygulamasını derleyip .app paketi oluşturur.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NamazVakti"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "▶︎ Release derleniyor…"
swift build -c release

echo "▸ .app paketi hazırlanıyor…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Namaz Vakti</string>
    <key>CFBundleIdentifier</key>
    <string>com.namazvakti.menubar</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Namaz vakitleri: Diyanet İşleri Başkanlığı (Awqat Salah API)</string>
</dict>
</plist>
PLIST

# Ad-hoc imzala (Keychain erişimi ve gatekeeper için).
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "✓ Hazır: $(pwd)/$APP_BUNDLE"
echo "  Çalıştır:  open \"$APP_BUNDLE\""
