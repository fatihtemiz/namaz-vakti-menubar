#!/bin/bash
# NamazVakti menü bar uygulamasını derleyip .app paketi ve paylaşılabilir DMG oluşturur.
#   ./build_app.sh           → NamazVakti.app + dist/NamazVakti-<sürüm>.dmg
#   ./build_app.sh install   → ayrıca ~/Applications'a kurar ve yeniden başlatır
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NamazVakti"
VERSION="1.2"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
ICON="Resources/AppIcon.icns"
DMG="dist/$APP_NAME-$VERSION.dmg"
MODE="${1:-}"

# İkon: yoksa ya da çizim betiği değiştiyse yeniden üret.
if [ ! -f "$ICON" ] || [ Scripts/make_icon.swift -nt "$ICON" ]; then
    echo "▸ İkon üretiliyor…"
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    swift Scripts/make_icon.swift "$ICONSET"
    mkdir -p Resources
    iconutil -c icns "$ICONSET" -o "$ICON"
    rm -rf "$(dirname "$ICONSET")"
fi

echo "▶︎ Release derleniyor…"
swift build -c release

echo "▸ .app paketi hazırlanıyor…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

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
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>tr</string>
        <string>en</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.lifestyle</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Namaz vakitleri: Diyanet İşleri Başkanlığı (EzanVakti API)</string>
</dict>
</plist>
PLIST

# Ad-hoc imzala (Keychain erişimi ve gatekeeper için).
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "▸ DMG hazırlanıyor…"
mkdir -p dist
STAGING="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Namaz Vakti" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ Hazır: $(pwd)/$APP_BUNDLE"
echo "✓ DMG:   $(pwd)/$DMG"

if [ "$MODE" = "install" ]; then
    echo "▸ ~/Applications'a kuruluyor…"
    pkill -x "$APP_NAME" || true
    mkdir -p ~/Applications
    rm -rf ~/Applications/"$APP_BUNDLE"
    cp -R "$APP_BUNDLE" ~/Applications/
    open ~/Applications/"$APP_BUNDLE"
    echo "✓ Kuruldu ve başlatıldı."
else
    echo "  Çalıştır:  open \"$APP_BUNDLE\"   (kurmak için: ./build_app.sh install)"
fi
